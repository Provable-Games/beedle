#[starknet::contract]
pub(crate) mod MockTWAMM {
    use ekubo::extensions::interfaces::twamm::{
        ITWAMM, OrderKey, OrderInfo, StateKey, SaleRateState, UpdateSaleRateCallbackData,
        CollectProceedsCallbackData, ForwardCallbackData,
    };
    use ekubo::types::fees_per_liquidity::FeesPerLiquidity;
    use ekubo::types::i129::i129;
    use starknet::ContractAddress;
    use core::dict::DictTrait;
    use core::dict::Dict;

    #[storage]
    struct Storage {
        // You can store any necessary state here
        // For the mock, we'll keep it simple
        order_infos: Dict<(ContractAddress, felt252, OrderKey), OrderInfo>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize storage variables if needed
        self.order_infos = Dict::default();
    }

    #[abi]
    impl ITWAMMImpl of ITWAMM<ContractState> {
        fn get_order_info(
            self: @ContractState, owner: ContractAddress, salt: felt252, order_key: OrderKey,
        ) -> OrderInfo {
            // Return a dummy OrderInfo or retrieve from storage if needed
            OrderInfo {
                sale_rate: 0_u128, remaining_sell_amount: 0_u128, purchased_amount: 0_u128,
            }
        }

        fn get_sale_rate_and_last_virtual_order_time(
            self: @ContractState, key: StateKey,
        ) -> SaleRateState {
            // Return a dummy SaleRateState
            SaleRateState {
                token0_sale_rate: 0_u128, token1_sale_rate: 0_u128, last_virtual_order_time: 0_u64,
            }
        }

        fn get_reward_rate(self: @ContractState, key: StateKey) -> FeesPerLiquidity {
            // Return a dummy FeesPerLiquidity
            FeesPerLiquidity { fee0_per_liquidity: 0_u128, fee1_per_liquidity: 0_u128, }
        }

        fn get_time_reward_rate_before(
            self: @ContractState, key: StateKey, time: u64,
        ) -> FeesPerLiquidity {
            // Return a dummy FeesPerLiquidity
            FeesPerLiquidity { fee0_per_liquidity: 0_u128, fee1_per_liquidity: 0_u128, }
        }

        fn get_sale_rate_net(self: @ContractState, key: StateKey, time: u64) -> u128 {
            // Return a dummy sale rate net
            0_u128
        }

        fn get_sale_rate_delta(self: @ContractState, key: StateKey, time: u64,) -> (i129, i129) {
            // Return dummy sale rate deltas
            (i129 { mag: 0_u128, sign: false }, i129 { mag: 0_u128, sign: false },)
        }

        fn next_initialized_time(
            self: @ContractState, key: StateKey, from: u64, max_time: u64,
        ) -> (u64, bool) {
            // Return dummy next initialized time
            (max_time, false)
        }

        fn execute_virtual_orders(ref self: ContractState, key: StateKey) { // Dummy implementation
        }

        fn update_call_points(ref self: ContractState) { // Dummy implementation
        }
    }
}
