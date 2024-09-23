use starknet::ContractAddress;

#[starknet::interface]
pub trait IEkuboDistributedERC20<TContractState> {
    fn init_distribution_pool(ref self: TContractState);
    fn start_token_distribution(ref self: TContractState);
    fn claim_and_sell_proceeds(ref self: TContractState);
    fn get_token_distribution_rate(self: @TContractState) -> u128;
    fn get_rewards_distribution_rate(self: @TContractState) -> u128;
    fn get_distribution_end_time(self: @TContractState) -> u64;
    fn get_pool_id(self: @TContractState) -> u256;
    fn get_position_token_id(self: @TContractState) -> u64;
    fn get_proceeds_distribution_duration(self: @TContractState) -> u64;
    fn get_proceeds_token(self: @TContractState) -> ContractAddress;
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn get_extension_address(self: @TContractState) -> ContractAddress;
    fn get_purchase_token(self: @TContractState) -> ContractAddress;
}
