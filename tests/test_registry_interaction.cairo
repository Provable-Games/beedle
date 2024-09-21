use core::result::ResultTrait;
use ekubo::interfaces::erc20::IERC20Dispatcher;
use ekubo::interfaces::token_registry::{ITokenRegistryDispatcher, ITokenRegistryDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::contract_address_const;

#[test]
fn test_registry_interaction_isolated() {
    // Deploy mock registry
    let registry = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry.deploy(@array![]).unwrap();

    // Deploy mock ERC20
    let mock_erc20 = declare("MockERC20").unwrap().contract_class();
    let mut calldata = array![];
    let name: ByteArray = "Test";
    name.serialize(ref calldata);
    let symbol: ByteArray = "TST";
    symbol.serialize(ref calldata);
    let supply: u256 = 1000;
    supply.serialize(ref calldata);
    let owner = contract_address_const::<0x123>();
    owner.serialize(ref calldata);

    let (token_address, _) = mock_erc20.deploy(@calldata).unwrap();

    // Try to register token
    let registry_dispatcher = ITokenRegistryDispatcher { contract_address: registry_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This should work if interfaces are compatible
    registry_dispatcher.register_token(token_dispatcher);
}
