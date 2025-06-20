use ekubo::extensions::interfaces::twamm::OrderKey;
use ekubo::types::keys::PoolKey;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IEkuboDistributedERC20<TContractState> {
    fn init_distribution_pool(ref self: TContractState);
    fn start_token_distribution(ref self: TContractState, end_time: u64);
    fn claim_and_sell_proceeds(ref self: TContractState);
    fn get_deployed_at(self: @TContractState) -> u64;
    fn get_distribution_end_time(self: @TContractState) -> u64;
    fn get_distribution_order_key(self: @TContractState) -> OrderKey;
    fn get_distribution_pool_key(self: @TContractState) -> PoolKey;
    fn get_distribution_start_time(self: @TContractState) -> u64;
    fn get_extension_address(self: @TContractState) -> ContractAddress;
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn get_pool_fee(self: @TContractState) -> u128;
    fn get_pool_id(self: @TContractState) -> u256;
    fn get_position_token_id(self: @TContractState) -> u64;
    fn get_reward_distribution_duration(self: @TContractState) -> u64;
    fn get_reward_distribution_rate(self: @TContractState) -> u128;
    fn get_reward_order_key(self: @TContractState) -> OrderKey;
    fn get_reward_token(self: @TContractState) -> ContractAddress;
    fn get_token_distribution_rate(self: @TContractState) -> u128;
    fn get_tick_spacing(self: @TContractState) -> u32;
    // TODO: add pool key hash
}
