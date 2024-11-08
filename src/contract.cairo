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
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::interfaces::token_registry::{
        ITokenRegistryDispatcher, ITokenRegistryDispatcherTrait
    };
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    use starknet::{get_contract_address, ContractAddress, storage::{Map}};
    use gerc20::constants::{
        Errors, MAX_TICK_SPACING, get_core_address, get_positions_address,
        get_twamm_extension_address, get_registry_address, FULL_RANGE, MAX_DURATION_SECONDS,
        VALID_END_TIME_MULTIPLE
    };
    use gerc20::interfaces::IEkuboDistributedERC20;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        core_dispatcher: ICoreDispatcher,
        deployed_at_timestamp: u64,
        distribution_end_time: u64,
        distribution_pool_fee: u128,
        distribution_start_time: u64,
        liquidity_promotion_lockup_duration_seconds: u64,
        liquidity_promotion_map: Map::<u64, u64>,
        payment_token_dispatcher: IERC20Dispatcher,
        pool_fee: u128,
        pool_id: u256,
        positions_dispatcher: IPositionsDispatcher,
        positions_nft_dispatcher: IERC721Dispatcher,
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
        ERC20Event: ERC20Component::Event,
    }

    /// @notice Initializes the EkuboDistributedERC20 contract
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param pool_fee The fee for the pool
    /// @param end_time The end time of the token distribution
    /// @param distribution_start_time The delay for the token distribution
    /// @param payment_token The address of the token used for payments
    /// @param reward_token The address of the token to be purchased with proceeds
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        pool_fee: u128,
        distribution_rate_tokens_per_day: u64,
        distribution_duration_days: u16,
        distribution_start_time: u64,
        reward_distribution_duration: u64,
        liquidity_promotion_lockup_duration_seconds: u64,
        payment_token: ContractAddress,
        reward_token: ContractAddress,
    ) {
        // init erc20
        self.erc20.initializer(name, symbol);

        self.reward_token.write(reward_token);
        self.deployed_at_timestamp.write(starknet::get_block_timestamp());
        self.pool_fee.write(pool_fee);
        self.distribution_start_time.write(distribution_start_time);
        self.reward_distribution_duration.write(reward_distribution_duration);

        let chain_id = get_tx_info().unbox().chain_id;

        // @dev since twamm extension address is chain dependent and it'll be used a lot
        // we store it here for efficient future access
        self.twamm_extension_address.write(get_twamm_extension_address(chain_id));

        // store payment token dispatcher
        self.payment_token_dispatcher.write(IERC20Dispatcher { contract_address: payment_token });

        // store core dispatcher
        let core_address = get_core_address(chain_id);
        let core_dispatcher = ICoreDispatcher { contract_address: core_address };
        self.core_dispatcher.write(core_dispatcher);

        // store positions dispatcher
        let positions_address = get_positions_address(chain_id);
        let positions_dispatcher = IPositionsDispatcher { contract_address: positions_address };
        self.positions_dispatcher.write(positions_dispatcher);

        // store positions nft dispatcher
        let positions_nft_address = positions_dispatcher.get_nft_address();
        let positions_nft_dispatcher = IERC721Dispatcher {
            contract_address: positions_nft_address
        };
        self.positions_nft_dispatcher.write(positions_nft_dispatcher);

        // store registry dispatcher
        let registry_address = get_registry_address(chain_id);
        let registry_dispatcher = ITokenRegistryDispatcher { contract_address: registry_address };
        self.registry_dispatcher.write(registry_dispatcher);

        // assert the liquidity promotion duration is either 0 or greater than the current time
        assert(
            liquidity_promotion_lockup_duration_seconds == 0
                || liquidity_promotion_lockup_duration_seconds > starknet::get_block_timestamp(),
            Errors::INVALID_LIQUIDITY_PROMOTION_DURATION
        );
        self
            .liquidity_promotion_lockup_duration_seconds
            .write(liquidity_promotion_lockup_duration_seconds);

        // register new token with ekubo registry
        _register_token(ref self);

        // initialize distribution pool
        _init_distribution_pool(ref self);

        // start token distribution
        _init_token_distribution(
            ref self,
            distribution_rate_tokens_per_day,
            distribution_duration_days,
            distribution_start_time
        );
    }

    #[abi(embed_v0)]
    impl EkuboDistributedERC20Impl of IEkuboDistributedERC20<ContractState> {
        fn provide_initial_liquidity(ref self: ContractState, amount: u64) -> (u128, u64, u64) {
            // assert distribution has not started
            assert(
                starknet::get_block_timestamp() < self.distribution_start_time.read(),
                Errors::DISTRIBUTION_ALREADY_STARTED
            );

            let caller_address = starknet::get_caller_address();
            let payment_token_dispatcher = self.payment_token_dispatcher.read();
            let positions_dispatcher = self.positions_dispatcher.read();

            // Transfer payment token from the caller to the position contract
            payment_token_dispatcher
                .transfer_from(
                    caller_address, positions_dispatcher.contract_address, amount.into()
                );

            // TODO: here we need to calculate amount of the Consumable based on the initial tick
            // configuration for example if this is the Attack Potion with a starting price of 1/2
            // of a $lord then if they provided 10 $lords we should mint 20 Attack Potions
            // mint Consumable side to the positions contract
            self.erc20.mint(positions_dispatcher.contract_address, amount.into());

            // Get the existing pool_key from the contract
            let pool_key = self.get_distribution_pool_key();

            // deposit liquidity
            let (position_token_id, provided_liquidity, _, _) = positions_dispatcher
                .mint_and_deposit_and_clear_both(pool_key, FULL_RANGE, 0);

            // mint the liquidity provider a blank Ekubo Position NFT
            // @dev we do this becasue we can't give them the actual position NFT otherwise they
            // could immediately reclaim their liquidity including the promotional Consumables
            // Giving them a blank NFT provides them with transferrable ownership of the underlying
            // liquidity
            let position_owner_token_id = positions_dispatcher.mint_v2(get_contract_address());

            // map the blank position NFT to the actual position token for future auth
            self.liquidity_promotion_map.write(position_owner_token_id, position_token_id);

            // transfer the position owner NFT to the liquidity provider (caller)
            let positions_nft_address = positions_dispatcher.get_nft_address();
            // create ERC721 Dispatcher
            let erc721_dispatcher = IERC721Dispatcher { contract_address: positions_nft_address };
            erc721_dispatcher
                .transfer_from(
                    get_contract_address(), caller_address, position_owner_token_id.into()
                );

            (provided_liquidity, position_token_id, position_owner_token_id)
        }

        fn claim_initial_liquidity(ref self: ContractState, position_owner_token_id: u64) {
            // assert the caller owns the position owner token id
            let caller_address = starknet::get_caller_address();
            let current_time = starknet::get_block_timestamp();
            let positions_nft_dispatcher = self.positions_nft_dispatcher.read();
            let owner = positions_nft_dispatcher.owner_of(position_owner_token_id.into());
            assert(owner == caller_address, Errors::NOT_POSITION_TOKEN_OWNER);

            // transfer the position owner NFT to the liquidity provider (caller)
            // get the position token id from the liquidity promotion map
            let position_token_id = self.liquidity_promotion_map.read(position_owner_token_id);
            let positions_dispatcher = self.positions_dispatcher.read();
            let pool_key = self.get_distribution_pool_key();

            // get liquidity from the position
            let liquidity = positions_dispatcher
                .get_token_info(position_token_id, pool_key, FULL_RANGE)
                .liquidity;

            // withdraw liquidity
            let (token0_amount, token1_amount) = positions_dispatcher
                .withdraw_v2(position_token_id, pool_key, FULL_RANGE, liquidity, 0, 0);

            // collect fees
            let (token0_fees, token1_fees) = positions_dispatcher
                .collect_fees(position_token_id, pool_key, FULL_RANGE);

            // add liquidity and fees
            let token0_total = token0_amount + token0_fees;
            let token1_total = token1_amount + token1_fees;

            // if provider waited for promotional period
            if current_time > liquidity_promotion_lockup_end_time(@self) {
                // they get both sides of the liquidity
                distribute_full_liquidity(ref self, pool_key, token0_total, token1_total);
            } else {
                // they get their initial liquidity back
                refund_initial_liquidity(ref self, pool_key, token0_total, token1_total);
            }
        }

        /// @notice Claims proceeds from selling tokens and uses them to buy the game token
        /// @dev This function can be called periodically to reinvest proceeds
        fn claim_and_sell_proceeds(ref self: ContractState) {
            _assert_token_distribution_started(@self);

            let positions_dispatcher = self.positions_dispatcher.read();
            let position_token_id = self.position_token_id.read();
            let order_key = _get_distribution_order_key(@self);
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

        fn get_deployed_at_timestamp(self: @ContractState) -> u64 {
            _get_deployed_at_timestamp(self)
        }

        fn get_distribution_end_time(self: @ContractState) -> u64 {
            _get_distribution_end_time(self)
        }

        fn get_distribution_order_key(self: @ContractState) -> OrderKey {
            _get_distribution_order_key(self)
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

        fn get_payment_token_address(self: @ContractState) -> ContractAddress {
            _get_payment_token_address(self)
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

    fn _get_deployed_at_timestamp(self: @ContractState) -> u64 {
        self.deployed_at_timestamp.read()
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

    fn _get_payment_token_address(self: @ContractState) -> ContractAddress {
        self.payment_token_dispatcher.read().contract_address
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
        let payment_token = _get_payment_token_address(self);
        let fee = _get_pool_fee(self);
        let tick_spacing = MAX_TICK_SPACING.into();
        let extension = _get_twamm_extension_address(self);

        // ekubo requires token0 to be less than token1
        let (token0, token1) = if this_token < payment_token {
            (this_token, payment_token)
        } else {
            (payment_token, this_token)
        };

        PoolKey { token0, token1, fee, tick_spacing, extension }
    }

    /// @notice Creates an OrderKey for the distribution token order
    /// @return OrderKey The key for the distribution token order
    fn _get_distribution_order_key(self: @ContractState) -> OrderKey {
        OrderKey {
            sell_token: get_contract_address(),
            buy_token: _get_payment_token_address(self),
            fee: _get_pool_fee(self),
            start_time: _get_distribution_start_time(self),
            end_time: _get_distribution_end_time(self),
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
            buy_token: _get_payment_token_address(self),
            fee: _get_pool_fee(self),
            start_time: current_time,
            end_time: valid_end_time,
        }
    }

    fn liquidity_promotion_lockup_end_time(self: @ContractState) -> u64 {
        self.deployed_at_timestamp.read() + self.liquidity_promotion_lockup_duration_seconds.read()
    }

    fn distribute_full_liquidity(
        ref self: ContractState, pool_key: PoolKey, token0_amount: u128, token1_amount: u128
    ) {
        let caller_address = starknet::get_caller_address();
        let payment_token_dispatcher = self.payment_token_dispatcher.read();

        let (consumable_tokens, initial_liquidity_tokens) = if pool_key
            .token0 == get_contract_address() {
            (token0_amount, token1_amount)
        } else {
            (token1_amount, token0_amount)
        };

        self.erc20.transfer(caller_address, consumable_tokens.into());
        payment_token_dispatcher.transfer(caller_address, initial_liquidity_tokens.into());
    }

    fn refund_initial_liquidity(
        ref self: ContractState, pool_key: PoolKey, token0_amount: u128, token1_amount: u128
    ) {
        let caller_address = starknet::get_caller_address();
        let payment_token_dispatcher = self.payment_token_dispatcher.read();

        let (consumable_tokens, initial_liquidity_tokens) = if pool_key
            .token0 == get_contract_address() {
            (token0_amount, token1_amount)
        } else {
            (token1_amount, token0_amount)
        };

        // burn consumables
        self.erc20.burn(get_contract_address(), consumable_tokens.into());

        // refund initial liquidity
        payment_token_dispatcher.transfer(caller_address, initial_liquidity_tokens.into());
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
        let erc20_dispatcher = ekubo::interfaces::erc20::IERC20Dispatcher {
            contract_address: get_contract_address()
        };
        registry_dispatcher.register_token(erc20_dispatcher);
    }

    fn _init_distribution_pool(ref self: ContractState) {
        assert(self.pool_id.read() == 0, Errors::DISTRIBUTION_POOL_ALREADY_INITIALIZED);
        let core_dispatcher = self.core_dispatcher.read();
        let initial_tick = i129 { mag: 0, sign: false };
        let pool_key = _get_distribution_pool_key(@self);
        let pool_id = core_dispatcher.initialize_pool(pool_key, initial_tick);
        self.pool_id.write(pool_id);
    }

    fn _init_token_distribution(
        ref self: ContractState,
        distribution_rate_tokens_per_day: u64,
        distribution_duration_days: u16,
        distribution_start_time: u64
    ) {
        // token supply is the distribution rate multiplied by the distribution duration
        let token_supply: u128 = distribution_rate_tokens_per_day.into()
            * distribution_duration_days.into();

        // mint entire supply to the positions contract
        let positions_dispatcher = self.positions_dispatcher.read();
        self.erc20.mint(positions_dispatcher.contract_address, token_supply.into());

        // round provided start time to nearest valid time
        let start_time = (distribution_start_time / 16) * 16;

        // convert distribution duration to seconds
        let distribution_duration_seconds: u64 = distribution_duration_days.into() * 86400;

        // assert distribution duration is within allowed limit
        assert(
            distribution_duration_seconds <= MAX_DURATION_SECONDS.into(),
            Errors::DISTRIBUTION_DURATION_TOO_LONG
        );

        // round end time to nearest valid time
        let end_time = ((start_time + distribution_duration_seconds)
            / VALID_END_TIME_MULTIPLE.into())
            * VALID_END_TIME_MULTIPLE.into();

        // store distribution start and end times
        self.distribution_start_time.write(start_time);
        self.distribution_end_time.write(end_time);

        let order_key = _get_distribution_order_key(@self);
        let (position_token_id, sale_rate) = positions_dispatcher
            .mint_and_increase_sell_amount(order_key, token_supply.try_into().unwrap());

        self.position_token_id.write(position_token_id);
        self.token_distribution_rate.write(sale_rate);
    }

    fn _assert_distribution_delay_passed(self: @ContractState) {
        let current_time = starknet::get_block_timestamp();
        let start_time = self.deployed_at_timestamp.read() + self.distribution_start_time.read();
        assert(current_time >= start_time, Errors::DISTRIBUTION_DELAY_STILL_ACTIVE);
    }

    fn _assert_token_distribution_not_started(self: @ContractState) {
        assert(self.position_token_id.read() == 0, Errors::TOKEN_DISTRIBUTION_ALREADY_STARTED);
    }

    fn _assert_token_distribution_started(self: @ContractState) {
        assert(self.position_token_id.read() != 0, Errors::TOKEN_DISTRIBUTION_NOT_STARTED);
    }
}
