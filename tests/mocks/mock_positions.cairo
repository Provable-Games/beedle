// Mock Positions contract that only implements methods used by EkuboDistributedERC20
#[starknet::contract]
mod MockPositions {
    use ekubo::extensions::interfaces::twamm::OrderKey;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        token_id_counter: u64,
        sale_rate_counter: u128,
    }

    #[external(v0)]
    fn mint_and_increase_sell_amount(
        ref self: ContractState, order_key: OrderKey, amount: u128,
    ) -> (u64, u128) {
        // Increment first so we start at 1, not 0
        let new_token_id = self.token_id_counter.read() + 1;
        self.token_id_counter.write(new_token_id);

        let sale_rate = amount / (order_key.end_time - order_key.start_time).into();
        self.sale_rate_counter.write(sale_rate);

        (new_token_id, sale_rate)
    }

    #[external(v0)]
    fn withdraw_proceeds_from_sale_to_self(
        ref self: ContractState, id: u64, order_key: OrderKey,
    ) -> u128 {
        // Mock implementation - return a fixed amount
        1000
    }

    #[external(v0)]
    fn increase_sell_amount(
        ref self: ContractState, id: u64, order_key: OrderKey, amount: u128,
    ) -> u128 {
        let sale_rate = amount / (order_key.end_time - order_key.start_time).into();
        sale_rate
    }
}
