// Mock Token Registry contract
#[starknet::contract]
mod MockTokenRegistry {
    use ekubo::interfaces::erc20::IERC20Dispatcher;
    use starknet::ContractAddress;
    use starknet::storage::{StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        pub registered_tokens: starknet::storage::Map<ContractAddress, bool>,
    }

    #[external(v0)]
    fn register_token(ref self: ContractState, token: IERC20Dispatcher) {
        self.registered_tokens.write(token.contract_address, true);
    }
}
