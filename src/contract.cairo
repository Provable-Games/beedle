// TODO:
// 1. Add Burn function to the ERC20 Consumables
// 2. Add Claim Starter Kit function to the ERC20 Consumables

/// @title EkuboDistributedERC20
/// @notice A contract for distributing ERC20 tokens using Ekubo's TWAMM (Time-Weighted Average
/// Market Maker)
/// @dev This contract extends the ERC20 standard with distribution functionality
#[starknet::contract]
mod EkuboDistributedERC20 {
    use core::starknet::get_tx_info;
    use ekubo::extensions::interfaces::twamm::OrderKey;
    use ekubo::types::keys::PoolKey;
    use ekubo::types::i129::i129;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::erc20::IERC20Dispatcher;
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::interfaces::token_registry::{
        ITokenRegistryDispatcher, ITokenRegistryDispatcherTrait
    };
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{get_contract_address, ContractAddress};
    use gerc20::constants::{Errors, MAX_TICK_SPACING, get_core_address, get_positions_address, get_twamm_extension_address, get_registry_address};
    use gerc20::interfaces::IEkuboDistributedERC20;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        core_dispatcher: ICoreDispatcher,
        deployed_at: u64,
        distribution_start_delay: u64,
        distribution_end_time: u64,
        distribution_pool_fee: u128,
        distribution_start_time: u64,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        payment_token: ContractAddress,
        pool_fee: u128,
        pool_id: u256,
        positions_dispatcher: IPositionsDispatcher,
        position_token_id: u64,
        registry_dispatcher: ITokenRegistryDispatcher,
        reward_distribution_duration: u64,
        reward_token: ContractAddress,
        reward_distribution_rate: u128,
        token_distribution_rate: u128,
        twamm_extension_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    /// @notice Initializes the EkuboDistributedERC20 contract
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param token_supply The total supply of tokens to mint
    /// @param pool_fee The fee for the pool
    /// @param end_time The end time of the token distribution
    /// @param distribution_start_delay The delay for the token distribution
    /// @param payment_token The address of the token used for payments
    /// @param reward_token The address of the token to be purchased with proceeds
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        token_supply: u128,
        pool_fee: u128,
        distribution_rate_days: u64,
        distribution_duration_days: u64,
        distribution_start_delay_seconds: u64,
        reward_distribution_duration: u64,
        payment_token: ContractAddress,
        reward_token: ContractAddress,
    ) {
        // init erc20
        self.erc20.initializer(name, symbol);

        self.payment_token.write(payment_token);
        self.reward_token.write(reward_token);
        self.deployed_at.write(starknet::get_block_timestamp());
        self.pool_fee.write(pool_fee);
        self.distribution_start_delay.write(distribution_start_delay);
        self.reward_distribution_duration.write(reward_distribution_duration);

        let chain_id = get_tx_info().unbox().chain_id;
        let core_dispatcher = ICoreDispatcher { contract_address: get_core_address(chain_id) };
        let positions_dispatcher = IPositionsDispatcher { contract_address: get_positions_address(chain_id) };
        let registry_dispatcher = ITokenRegistryDispatcher { contract_address: get_registry_address(chain_id) };

        self.core_dispatcher.write(core_dispatcher);
        self.positions_dispatcher.write(positions_dispatcher);
        self.registry_dispatcher.write(registry_dispatcher);
        self.twamm_extension_address.write(get_twamm_extension_address(chain_id));
        
        // register new token with ekubo registry
        _register_token(ref self);

        // initialize distribution pool
        _init_distribution_pool(ref self);
    }

    #[abi(embed_v0)]
    impl EkuboDistributedERC20Impl of IEkuboDistributedERC20<ContractState> {
        /// @notice Starts the token distribution
        /// @dev This function can only be called once, after the distribution delay has passed
        fn start_token_distribution(ref self: ContractState) {
            _assert_distribution_delay_passed(@self);
            _assert_distribution_pool_initialized(@self);
            _assert_token_distribution_not_started(@self);
            _start_token_distribution(ref self);
        }

        /// @notice Claims proceeds from selling tokens and uses them to buy the game token
        /// @dev This function can be called periodically to reinvest proceeds
        fn claim_and_sell_proceeds(ref self: ContractState) {
            _assert_token_distribution_started(@self);

            let positions_dispatcher = self.positions_dispatcher.read();
            let position_token_id = self.position_token_id.read();
            let start_time = _get_distribution_start_time(@self);
            let end_time = _get_distribution_end_time(@self);
            let order_key = _get_distribution_order_key(@self, start_time, end_time);
            let proceeds = positions_dispatcher
                .withdraw_proceeds_from_sale_to_self(position_token_id, order_key);

            // sell proceeds for the primary game token
            let reward_token_order_key = _get_reward_order_key(@self);
            let sale_rate_increase = positions_dispatcher
                .increase_sell_amount(position_token_id, reward_token_order_key, proceeds,);

            // update the rewards distribution rate
            let previous_sale_rate = self.reward_distribution_rate.read();
            let new_sale_rate = previous_sale_rate + sale_rate_increase;
            self.reward_distribution_rate.write(new_sale_rate);
        }

        fn get_token_distribution_rate(self: @ContractState) -> u128 {
            _get_token_distribution_rate(self)
        }

        fn get_reward_distribution_rate(self: @ContractState) -> u128 {
            _get_reward_distribution_rate(self)
        }

        fn get_deployed_at(self: @ContractState) -> u64 {
            _get_deployed_at(self)
        }

        fn get_distribution_end_time(self: @ContractState) -> u64 {
            _get_distribution_end_time(self)
        }

        fn get_distribution_order_key(self: @ContractState) -> OrderKey {
            let start_time = _get_distribution_start_time(self);
            let end_time = _get_distribution_end_time(self);
            _get_distribution_order_key(self, start_time, end_time)
        }

        fn get_distribution_pool_key(self: @ContractState) -> PoolKey {
            _get_distribution_pool_key(self)
        }

        fn get_distribution_start_time(self: @ContractState) -> u64 {
            _get_distribution_start_time(self)
        }

        fn get_pool_fee(self: @ContractState) -> u128 {
            _get_pool_fee(self)
        }

        fn get_pool_id(self: @ContractState) -> u256 {
            _get_pool_id(self)
        }

        fn get_position_token_id(self: @ContractState) -> u64 {
            _get_position_token_id(self)
        }

        fn get_reward_distribution_duration(self: @ContractState) -> u64 {
            _get_reward_distribution_duration(self)
        }

        fn get_reward_order_key(self: @ContractState) -> OrderKey {
            _get_reward_order_key(self)
        }

        fn get_payment_token(self: @ContractState) -> ContractAddress {
            _get_payment_token(self)
        }

        fn get_twamm_extension_address(self: @ContractState) -> ContractAddress {
            _get_twamm_extension_address(self)
        }

        fn get_reward_token(self: @ContractState) -> ContractAddress {
            _get_reward_token(self)
        }
    }

    fn _get_token_distribution_rate(self: @ContractState) -> u128 {
        self.token_distribution_rate.read()
    }

    fn _get_reward_distribution_rate(self: @ContractState) -> u128 {
        self.reward_distribution_rate.read()
    }

    fn _get_deployed_at(self: @ContractState) -> u64 {
        self.deployed_at.read()
    }

    fn _get_distribution_end_time(self: @ContractState) -> u64 {
        self.distribution_end_time.read()
    }

    fn _get_distribution_start_time(self: @ContractState) -> u64 {
        self.distribution_start_time.read()
    }

    fn _get_pool_fee(self: @ContractState) -> u128 {
        self.pool_fee.read()
    }

    fn _get_pool_id(self: @ContractState) -> u256 {
        self.pool_id.read()
    }

    fn _get_position_token_id(self: @ContractState) -> u64 {
        self.position_token_id.read()
    }

    fn _get_reward_distribution_duration(self: @ContractState) -> u64 {
        self.reward_distribution_duration.read()
    }

    fn _get_payment_token(self: @ContractState) -> ContractAddress {
        self.payment_token.read()
    }

    fn _get_twamm_extension_address(self: @ContractState) -> ContractAddress {
        self.twamm_extension_address.read()
    }

    fn _get_reward_token(self: @ContractState) -> ContractAddress {
        self.reward_token.read()
    }

    /// @notice Creates a PoolKey for the distribution token pool
    /// @return PoolKey The key for the distribution token pool
    fn _get_distribution_pool_key(self: @ContractState) -> PoolKey {
        let this_token = get_contract_address();
        let payment_token = _get_payment_token(self);
        if this_token < payment_token {
            PoolKey {
                token0: this_token,
                token1: payment_token,
                fee: _get_pool_fee(self),
                tick_spacing: MAX_TICK_SPACING.into(),
                extension: _get_twamm_extension_address(self),
            }
        } else {
            PoolKey {
                token0: payment_token,
                token1: this_token,
                fee: _get_pool_fee(self),
                tick_spacing: MAX_TICK_SPACING.into(),
                extension: _get_twamm_extension_address(self),
            }
        }
    }

    /// @notice Creates an OrderKey for the distribution token order
    /// @param start_time The start time of the order
    /// @param end_time The end time of the order
    /// @return OrderKey The key for the distribution token order
    fn _get_distribution_order_key(
        self: @ContractState, start_time: u64, end_time: u64
    ) -> OrderKey {
        OrderKey {
            sell_token: get_contract_address(),
            buy_token: _get_payment_token(self),
            fee: _get_pool_fee(self),
            start_time: start_time,
            end_time: end_time, 
        }
    }

    /// @notice Creates an OrderKey for purchasing tokens with proceeds
    /// @return OrderKey The key for the purchase token order
    fn _get_reward_order_key(self: @ContractState) -> OrderKey {
        let current_time = starknet::get_block_timestamp();
        let end_time = current_time + _get_reward_distribution_duration(self);
        let valid_end_time = _to_nearest_valid_time(current_time, end_time);
        OrderKey {
            sell_token: _get_reward_token(self),
            buy_token: _get_payment_token(self),
            fee: _get_pool_fee(self),
            start_time: current_time,
            end_time: valid_end_time,
        }
    }

    fn _to_nearest_valid_time(block_time: u64, time: u64) -> u64 {
        let diff = time - block_time;

        if diff < 256 {
            return (time + 15) / 16 * 16;
        }

        let step_size = _time_difference_to_step_size(diff);
        let modulo = time % step_size;

        if modulo == 0 {
            return time;
        }

        let next = time + (step_size - modulo);
        _to_nearest_valid_time(block_time, next)
    }

    fn _time_difference_to_step_size(diff: u64) -> u64 {
        if diff < 256 {
            return 16;
        }

        let mut result = 16;
        let mut temp = diff;

        loop {
            if temp < 16 {
                break;
            }
            temp = temp / 16;
            result = result * 16;
        };

        result
    }

    fn _register_token(ref self: ContractState) {
        // mint 1 token to registry contract to register it
        let registry_dispatcher = self.registry_dispatcher.read();
        self.erc20.mint(registry_dispatcher.contract_address, 1000000000000000000);

        // call register_token on the registry contract
        let erc20_dispatcher = IERC20Dispatcher { contract_address: get_contract_address() };
        registry_dispatcher.register_token(erc20_dispatcher);

    }

    fn _init_distribution_pool(ref self: ContractState) {
        assert(self.pool_id.read() == 0, Errors::DISTRIBUTION_POOL_ALREADY_INITIALIZED);
        let core_dispatcher = self.core_dispatcher.read();
        let initial_tick = i129 { mag: 0, sign: false };
        let pool_key = _get_distribution_pool_key(@self);
        let pool_id = core_dispatcher.initialize_pool(pool_key, initial_tick);

        // deposit some initial liquidity into the pool (1 $lord and 1 $new_token)
        // https://github.com/EkuboProtocol/abis/blob/edb6de8c9baf515f1053bbab3d86825d54a63bc3/src/interfaces/positions.cairo#L99-L109
        self.pool_id.write(pool_id);
    }

    fn _start_token_distribution(ref self: ContractState) {
        let block_time = starknet::get_block_timestamp();
        let start_time = (block_time / 16) * 16;

        // mint token supply to the positions contract
        let positions_dispatcher = self.positions_dispatcher.read();
        self.erc20.mint(self.positions_dispatcher.read().contract_address, token_supply.into());
        let order_key = _get_distribution_order_key(@self, start_time, end_time);
        let (position_token_id, sale_rate) = positions_dispatcher
            .mint_and_increase_sell_amount(order_key, token_supply.try_into().unwrap());

        self.distribution_start_time.write(start_time);
        self.distribution_end_time.write(end_time);
        self.position_token_id.write(position_token_id);
        self.token_distribution_rate.write(sale_rate);
    }

    fn _assert_distribution_delay_passed(self: @ContractState) {
        let current_time = starknet::get_block_timestamp();
        let start_time = self.deployed_at.read() + self.distribution_start_delay.read();
        assert(current_time >= start_time, Errors::DISTRIBUTION_DELAY_STILL_ACTIVE);
    }

    fn _assert_distribution_pool_initialized(self: @ContractState) {
        assert(self.pool_id.read() != 0, Errors::DISTRIBUTION_POOL_NOT_INITIALIZED);
    }

    fn _assert_token_distribution_not_started(self: @ContractState) {
        assert(self.position_token_id.read() == 0, Errors::TOKEN_DISTRIBUTION_ALREADY_STARTED);
    }

    fn _assert_token_distribution_started(self: @ContractState) {
        assert(self.position_token_id.read() != 0, Errors::TOKEN_DISTRIBUTION_NOT_STARTED);
    }
}
