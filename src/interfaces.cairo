#[starknet::interface]
pub trait IEkuboDistributedERC20<TContractState> {
    fn init_distribution_pool(ref self: TContractState);
    fn start_token_distribution(ref self: TContractState);
    fn claim_and_sell_proceeds(ref self: TContractState);
}