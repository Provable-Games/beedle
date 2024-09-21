/// @title EkuboDistributedERC20
/// @notice A contract for distributing ERC20 tokens using Ekubo's TWAMM (Time-Weighted Average
/// Market Maker)
/// @dev This contract extends the ERC20 standard with distribution functionality
#[starknet::contract]
mod EkuboDistributedERC20 {
    use ekubo::extensions::interfaces::twamm::OrderKey;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::interfaces::token_registry::{
        ITokenRegistryDispatcher, ITokenRegistryDispatcherTrait,
    };
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use gerc20::constants::Errors;
    use gerc20::interfaces::IEkuboDistributedERC20;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_contract_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        pub core_dispatcher: ICoreDispatcher,
        pub deployed_at: u64,
        pub distribution_end_time: u64,
        pub distribution_pool_fee: u128,
        pub distribution_start_time: u64,
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        pub extension_address: ContractAddress,
        pub payment_token: ContractAddress,
        pub pool_fee: u128,
        pub pool_id: u256,
        pub positions_dispatcher: IPositionsDispatcher,
        pub position_token_id: u64,
        pub registry_dispatcher: ITokenRegistryDispatcher,
        pub reward_distribution_duration: u64,
        pub reward_token: ContractAddress,
        pub reward_distribution_rate: u128,
        pub tick_spacing: u32,
        pub token_distribution_rate: u128,
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
    /// @param total_supply The total supply of tokens to mint
    /// @param payment_token The address of the token used for payments
    /// @param reward_token The address of the token to be purchased with proceeds
    /// @param emission_duration The duration of the token distribution in seconds
    /// @param core_address The address of the Ekubo core contract
    /// @param positions_address The address of the Ekubo positions contract
    /// @param extension_address The address of the Ekubo extension contract
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        total_supply: u128,
        pool_fee: u128,
        tick_spacing: u32,
        payment_token: ContractAddress,
        reward_token: ContractAddress,
        core_address: ContractAddress,
        positions_address: ContractAddress,
        extension_address: ContractAddress,
        registry_address: ContractAddress,
    ) {
        // Validate constructor parameters
        let zero_address = starknet::contract_address_const::<0>();
        assert(payment_token != zero_address, 'Invalid payment token');
        assert(reward_token != zero_address, 'Invalid reward token');
        assert(core_address != zero_address, 'Invalid core address');
        assert(positions_address != zero_address, 'Invalid positions address');
        assert(extension_address != zero_address, 'Invalid extension address');
        assert(registry_address != zero_address, 'Invalid registry address');
        assert(total_supply > 0, 'Invalid total supply');

        // init erc20
        self.erc20.initializer(name, symbol);

        // store constructor params for getters
        self.payment_token.write(payment_token);
        self.reward_token.write(reward_token);
        let current_time = starknet::get_block_timestamp();
        self.core_dispatcher.write(ICoreDispatcher { contract_address: core_address });
        self
            .positions_dispatcher
            .write(IPositionsDispatcher { contract_address: positions_address });
        self.extension_address.write(extension_address);
        self.deployed_at.write(current_time);
        self.tick_spacing.write(tick_spacing);
        self.pool_fee.write(pool_fee);
        self
            .registry_dispatcher
            .write(ITokenRegistryDispatcher { contract_address: registry_address });

        // mint total supply to self
        self.erc20.mint(get_contract_address(), total_supply.into());

        // register token with registry
        _register_token(ref self);
    }

    #[abi(embed_v0)]
    impl EkuboDistributedERC20Impl of IEkuboDistributedERC20<ContractState> {
        /// @notice Initializes an Ekubo pool for distributing the token supply via a TWAMM order
        /// @dev This function should be called before starting the token distribution
        fn init_distribution_pool(ref self: ContractState) {
            assert(self.pool_id.read() == 0, Errors::DISTRIBUTION_POOL_ALREADY_INITIALIZED);
            let core_dispatcher = self.core_dispatcher.read();
            let initial_tick = i129 { mag: 0, sign: false };
            let pool_key = _get_distribution_pool_key(@self);
            let pool_id = core_dispatcher.initialize_pool(pool_key, initial_tick);
            self.pool_id.write(pool_id);
        }

        /// @notice Distributes the entire token supply using a TWAP order
        /// @param end_time The end time of the TWAP order
        /// @dev This function should be called after initializing the distribution pool
        fn start_token_distribution(ref self: ContractState, end_time: u64) {
            assert(self.pool_id.read() != 0, Errors::DISTRIBUTION_POOL_NOT_INITIALIZED);
            assert(self.position_token_id.read() == 0, Errors::TOKEN_DISTRIBUTION_ALREADY_STARTED);

            let block_time = starknet::get_block_timestamp();
            let start_time = (block_time / 16) * 16;

            // transfer entire token supply to the positions contract
            let positions_dispatcher = self.positions_dispatcher.read();
            let total_supply = self.erc20.total_supply();
            let order_key = _get_distribution_order_key(@self, start_time, end_time);
            let (position_token_id, sale_rate) = positions_dispatcher
                .mint_and_increase_sell_amount(order_key, total_supply.try_into().unwrap());

            self.distribution_start_time.write(start_time);
            self.distribution_end_time.write(end_time);
            self.position_token_id.write(position_token_id);
            self.token_distribution_rate.write(sale_rate);
        }

        /// @notice Claims proceeds from selling tokens and uses them to buy the game token
        /// @dev This function can be called periodically to reinvest proceeds
        fn claim_and_sell_proceeds(ref self: ContractState) {
            assert(self.pool_id.read() != 0, Errors::DISTRIBUTION_POOL_NOT_INITIALIZED);
            assert(
                self.position_token_id.read() != 0, Errors::TOKEN_DISTRIBUTION_NOT_STARTED,
            ); // withdraw proceeds
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
                .increase_sell_amount(position_token_id, reward_token_order_key, proceeds);

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

        fn get_extension_address(self: @ContractState) -> ContractAddress {
            _get_extension_address(self)
        }

        fn get_reward_token(self: @ContractState) -> ContractAddress {
            _get_reward_token(self)
        }

        fn get_tick_spacing(self: @ContractState) -> u32 {
            _get_tick_spacing(self)
        }
    }

    #[inline(always)]
    fn _get_token_distribution_rate(self: @ContractState) -> u128 {
        self.token_distribution_rate.read()
    }

    #[inline(always)]
    fn _get_reward_distribution_rate(self: @ContractState) -> u128 {
        self.reward_distribution_rate.read()
    }

    #[inline(always)]
    fn _get_deployed_at(self: @ContractState) -> u64 {
        self.deployed_at.read()
    }

    #[inline(always)]
    fn _get_distribution_end_time(self: @ContractState) -> u64 {
        self.distribution_end_time.read()
    }

    #[inline(always)]
    fn _get_distribution_start_time(self: @ContractState) -> u64 {
        self.distribution_start_time.read()
    }

    #[inline(always)]
    fn _get_pool_fee(self: @ContractState) -> u128 {
        self.pool_fee.read()
    }

    #[inline(always)]
    fn _get_pool_id(self: @ContractState) -> u256 {
        self.pool_id.read()
    }

    #[inline(always)]
    fn _get_position_token_id(self: @ContractState) -> u64 {
        self.position_token_id.read()
    }

    #[inline(always)]
    fn _get_reward_distribution_duration(self: @ContractState) -> u64 {
        assert(self.distribution_end_time.read() != 0, Errors::DISTRIBUTION_END_TIME_NOT_SET);
        let start_time = _get_distribution_start_time(self);
        let end_time = _get_distribution_end_time(self);
        end_time - start_time
    }

    #[inline(always)]
    fn _get_payment_token(self: @ContractState) -> ContractAddress {
        self.payment_token.read()
    }

    #[inline(always)]
    fn _get_extension_address(self: @ContractState) -> ContractAddress {
        self.extension_address.read()
    }

    #[inline(always)]
    fn _get_reward_token(self: @ContractState) -> ContractAddress {
        self.reward_token.read()
    }

    #[inline(always)]
    fn _get_tick_spacing(self: @ContractState) -> u32 {
        self.tick_spacing.read()
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
                tick_spacing: _get_tick_spacing(self).into(),
                extension: _get_extension_address(self),
            }
        } else {
            PoolKey {
                token0: payment_token,
                token1: this_token,
                fee: _get_pool_fee(self),
                tick_spacing: _get_tick_spacing(self).into(),
                extension: _get_extension_address(self),
            }
        }
    }

    /// @notice Creates an OrderKey for the distribution token order
    /// @param start_time The start time of the order
    /// @param end_time The end time of the order
    /// @return OrderKey The key for the distribution token order
    fn _get_distribution_order_key(
        self: @ContractState, start_time: u64, end_time: u64,
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
        let registry_dispatcher = self.registry_dispatcher.read();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: get_contract_address() };

        // transfer one token to registry contract
        erc20_dispatcher.transfer(registry_dispatcher.contract_address, 1);

        // call register_token on the registry contract
        registry_dispatcher.register_token(erc20_dispatcher);
    }
}
