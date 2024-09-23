#[starknet::contract]
pub(crate) mod MockCore {
    use starknet::ContractAddress;
    use ekubo::interfaces::core::{ICore};

    #[storage]
    struct Storage {
        // Store any necessary state, e.g., pool_id counter
        pool_id_counter: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.pool_id_counter.write(1_u256);
    }

    #[abi]
    impl ICoreImpl of ICore<ContractState> {
        fn initialize_pool(self: @ContractState, pool_key: PoolKey, initial_tick: i129) -> u256 {
            // Dummy implementation: Return an incrementing pool_id
            let pool_id = self.pool_id_counter.read();
            self.pool_id_counter.write(pool_id + 1_u256);
            pool_id
        }
        // Provide dummy implementations for any other functions your contract calls
    }
}
