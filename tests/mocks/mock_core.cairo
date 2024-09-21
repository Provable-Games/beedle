// Mock Core contract that only implements the method used by EkuboDistributedERC20
#[starknet::contract]
mod MockCore {
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        pool_id_counter: u256,
    }

    #[external(v0)]
    fn initialize_pool(ref self: ContractState, pool_key: PoolKey, initial_tick: i129) -> u256 {
        let pool_id = self.pool_id_counter.read();
        self.pool_id_counter.write(pool_id + 1);
        pool_id
    }
}
