#[starknet::contract]
pub(crate) mod MockPositions {
    use starknet::ContractAddress;
    use ekubo::extensions::interfaces::twamm::{OrderKey};
    use ekubo::interfaces::positions::{IPositions};
    use ekubo::types::pool_price::PoolPrice;

    #[storage]
    struct Storage {
        // Store any necessary state, e.g., position_token_id counter
        position_token_id_counter: u64,
        sale_rates: Dict<u64, u128>, // Mapping from position token ID to sale rate
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.position_token_id_counter.write(1_u64);
    }

    #[abi]
    impl IPositionsImpl of IPositions<ContractState> {
        fn mint_and_increase_sell_amount(
            ref self: ContractState, order_key: OrderKey, amount: u128,
        ) -> (u64, u128) {
            // Dummy implementation: Return an incrementing position token ID and a dummy sale rate
            let position_token_id = self.position_token_id_counter.read();
            self.position_token_id_counter.write(position_token_id + 1_u64);

            // Store the sale rate (for completeness)
            self.sale_rates.write(position_token_id, amount);

            // Return the position token ID and the amount as the sale rate
            (position_token_id, amount)
        }

        fn withdraw_proceeds_from_sale_to_self(
            ref self: ContractState, id: u64, order_key: OrderKey,
        ) -> u128 {
            // Dummy implementation: Return a fixed amount as proceeds
            100_u128 // Return 100 as dummy proceeds
        }

        fn increase_sell_amount(
            ref self: ContractState, id: u64, order_key: OrderKey, amount: u128,
        ) -> u128 {
            // Dummy implementation: Return the increase amount
            amount
        }
        // Provide dummy implementations for any other functions your contract calls
    }
}
