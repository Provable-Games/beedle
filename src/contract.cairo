/// @title EkuboDistributedERC20
/// @notice A contract for distributing ERC20 tokens using Ekubo's TWAMM (Time-Weighted Average Market Maker)
/// @dev This contract extends the ERC20 standard with distribution functionality
#[starknet::contract]
mod EkuboDistributedERC20 {
    use ekubo::extensions::interfaces::twamm::{OrderKey};
    use ekubo::types::keys::PoolKey;
    use ekubo::types::i129::i129;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{get_contract_address, ContractAddress};
    use gerc20::constants::Errors;
    use gerc20::interfaces::IEkuboDistributedERC20;

    const MAX_TICK_SPACING: u32 = 354892;
    const DISTRIBUTION_POOL_FEE: u128 = 3402823669209384634633746074317682114; // 1%

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        core_dispatcher: ICoreDispatcher,
        deployed_at: u64,
        distribution_end_time: u64,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        extension_address: ContractAddress,
        payment_token: ContractAddress,
        pool_id: u256,
        positions_dispatcher: IPositionsDispatcher,
        position_token_id: u64,
        proceeds_distribution_duration: u64,
        purchase_token: ContractAddress,
        rewards_distribution_rate: u128,
        sale_rate: u128,
        token_distribution_rate: u128,
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
    /// @param total_supply The total supply of tokens to mint
    /// @param payment_token The address of the token used for payments
    /// @param purchase_token The address of the token to be purchased with proceeds
    /// @param emission_duration The duration of the token distribution in seconds
    /// @param core_address The address of the Ekubo core contract
    /// @param positions_address The address of the Ekubo positions contract
    /// @param extension_address The address of the Ekubo extension contract
    /// @param proceeds_distribution_duration The duration for distributing proceeds in seconds
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        total_supply: u128,
        payment_token: ContractAddress,
        purchase_token: ContractAddress,
        emission_duration: u64,
        core_address: ContractAddress,
        positions_address: ContractAddress,
        extension_address: ContractAddress,
        proceeds_distribution_duration: u64,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(get_contract_address(), total_supply.into());
        self.payment_token.write(payment_token);
        self.purchase_token.write(purchase_token);
        let current_time = starknet::get_block_timestamp();
        self.distribution_end_time.write(current_time + emission_duration);
        self.core_dispatcher.write(ICoreDispatcher { contract_address: core_address });
        self
            .positions_dispatcher
            .write(IPositionsDispatcher { contract_address: positions_address });
        self.extension_address.write(extension_address);
        self.deployed_at.write(current_time);
        self.proceeds_distribution_duration.write(proceeds_distribution_duration);
    }

    #[abi(embed_v0)]
    impl EkuboDistributedERC20Impl of IEkuboDistributedERC20<ContractState> {
        /// @notice Initializes an Ekubo pool for distributing the token supply via a TWAMM order
        /// @dev This function should be called before starting the token distribution
        fn init_distribution_pool(ref self: ContractState) {
            let core_dispatcher = self.core_dispatcher.read();
            let initial_tick = i129 { mag: 0, sign: false };
            let pool_key = _distribution_token_pool_key(@self);
            let pool_id = core_dispatcher.initialize_pool(pool_key, initial_tick);
            self.pool_id.write(pool_id);
        }

        /// @notice Distributes the entire token supply using a TWAMM order
        /// @dev This function should be called after initializing the distribution pool
        fn start_token_distribution(ref self: ContractState) {
            assert(self.pool_id.read() != 0, Errors::DISTRIBUTION_POOL_NOT_INITIALIZED);
            assert(self.position_token_id.read() == 0, Errors::TOKEN_DISTRIBUTION_ALREADY_STARTED);
            let positions_dispatcher = self.positions_dispatcher.read();
            let order_key = _distribution_token_order_key(@self);
            let total_supply = self.erc20.total_supply().try_into().unwrap();
            let (position_token_id, sale_rate) = positions_dispatcher
                .mint_and_increase_sell_amount(order_key, total_supply);

            // store the position token id and sale rate
            self.position_token_id.write(position_token_id);
            self.token_distribution_rate.write(sale_rate);
        }

        /// @notice Claims proceeds from selling tokens and uses them to buy the game token
        /// @dev This function can be called periodically to reinvest proceeds
        fn claim_and_sell_proceeds(ref self: ContractState) {
            assert(self.pool_id.read() != 0, Errors::DISTRIBUTION_POOL_NOT_INITIALIZED);
            assert(self.position_token_id.read() != 0, Errors::TOKEN_DISTRIBUTION_NOT_STARTED);            // withdraw proceeds
            let positions_dispatcher = self.positions_dispatcher.read();
            let position_token_id = self.position_token_id.read();
            let order_key = _distribution_token_order_key(@self);
            let proceeds = positions_dispatcher
                .withdraw_proceeds_from_sale_to_self(position_token_id, order_key);

            // sell proceeds for the primary game token
            let purchase_token_order_key = _purchase_token_order_key(@self);
            let sale_rate_increase = positions_dispatcher
                .increase_sell_amount(position_token_id, purchase_token_order_key, proceeds,);

            // update the rewards distribution rate
            let previous_sale_rate = self.rewards_distribution_rate.read();
            let new_sale_rate = previous_sale_rate + sale_rate_increase;
            self.rewards_distribution_rate.write(new_sale_rate);
        }
    }

    /// @notice Creates a PoolKey for the distribution token pool
    /// @return PoolKey The key for the distribution token pool
    fn _distribution_token_pool_key(self: @ContractState) -> PoolKey {
        PoolKey {
            token0: get_contract_address(),
            token1: self.payment_token.read(),
            fee: DISTRIBUTION_POOL_FEE,
            tick_spacing: MAX_TICK_SPACING.into(),
            extension: self.extension_address.read(),
        }
    }

    /// @notice Creates an OrderKey for the distribution token order
    /// @return OrderKey The key for the distribution token order
    fn _distribution_token_order_key(self: @ContractState) -> OrderKey {
        OrderKey {
            sell_token: get_contract_address(),
            buy_token: self.payment_token.read(),
            fee: DISTRIBUTION_POOL_FEE,
            start_time: self.deployed_at.read(),
            end_time: self.distribution_end_time.read(),
        }
    }

    /// @notice Creates an OrderKey for purchasing tokens with proceeds
    /// @return OrderKey The key for the purchase token order
    fn _purchase_token_order_key(self: @ContractState) -> OrderKey {
        let current_time = starknet::get_block_timestamp();
        let distribution_duration = self.proceeds_distribution_duration.read();
        OrderKey {
            sell_token: self.purchase_token.read(),
            buy_token: self.payment_token.read(),
            fee: DISTRIBUTION_POOL_FEE,
            start_time: current_time,
            end_time: current_time + distribution_duration,
        }
    }
}
