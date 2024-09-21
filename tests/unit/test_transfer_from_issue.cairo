use core::result::ResultTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::contract_address_const;

// This test demonstrates the transfer_from issue in the EkuboDistributedERC20 constructor

#[test]
fn test_constructor_transfer_from_issue() {
    // The contract has a bug where it calls transfer_from on itself without approval
    // This test documents the issue

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Prepare valid constructor parameters
    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let payment_token = contract_address_const::<0x1234567890>();
    let reward_token = contract_address_const::<0x9876543210>();
    let core_address = contract_address_const::<0x1111111111>();
    let positions_address = contract_address_const::<0x2222222222>();
    let extension_address = contract_address_const::<0x3333333333>();

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    payment_token.serialize(ref constructor_calldata);
    reward_token.serialize(ref constructor_calldata);
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    // After the fix, deployment should succeed
    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
    // The error occurs at line 412 in contract.cairo:
// self.erc20.transfer_from(get_contract_address(), registry_dispatcher.contract_address, 1);
//
// This fails because:
// 1. The contract mints tokens to itself
// 2. Then tries to transfer_from itself to the registry
// 3. But it hasn't approved itself to spend its own tokens
//
// Fix: Use transfer() instead of transfer_from() since the contract owns the tokens
}
