use core::result::ResultTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ContractAddress, contract_address_const};

// Helper to prepare constructor calldata with default values
fn prepare_constructor_calldata(
    name: ByteArray,
    symbol: ByteArray,
    total_supply: u128,
    pool_fee: u128,
    tick_spacing: u32,
    payment_token: ContractAddress,
    reward_token: ContractAddress,
    core_address: ContractAddress,
    positions_address: ContractAddress,
    extension_address: ContractAddress,
    registry_address: ContractAddress,
) -> Array<felt252> {
    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    pool_fee.serialize(ref calldata);
    tick_spacing.serialize(ref calldata);
    payment_token.serialize(ref calldata);
    reward_token.serialize(ref calldata);
    core_address.serialize(ref calldata);
    positions_address.serialize(ref calldata);
    extension_address.serialize(ref calldata);
    registry_address.serialize(ref calldata);
    calldata
}

// UT_CONSTRUCTOR_REVERT_001: Zero payment_token address
#[test]
fn test_constructor_revert_zero_payment_token() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0>(), // Zero payment token
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero payment');
}

// UT_CONSTRUCTOR_REVERT_002: Zero reward_token address
#[test]
fn test_constructor_revert_zero_reward_token() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0>(), // Zero reward token
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero reward');
}

// UT_CONSTRUCTOR_REVERT_003: Zero core_address
#[test]
fn test_constructor_revert_zero_core_address() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0>(), // Zero core address
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero core');
}

// UT_CONSTRUCTOR_REVERT_004: Zero positions_address
#[test]
fn test_constructor_revert_zero_positions_address() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0>(), // Zero positions address
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero positions');
}

// UT_CONSTRUCTOR_REVERT_005: Zero extension_address
#[test]
fn test_constructor_revert_zero_extension_address() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0>(), // Zero extension address
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero extension');
}

// UT_CONSTRUCTOR_REVERT_006: Zero registry_address
#[test]
fn test_constructor_revert_zero_registry_address() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0>() // Zero registry address
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero registry');
}

// UT_CONSTRUCTOR_REVERT_007: Zero total_supply
#[test]
fn test_constructor_revert_zero_total_supply() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let calldata = prepare_constructor_calldata(
        "Test Token",
        "TEST",
        0, // Zero total supply
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
        contract_address_const::<0x4444444444>(),
    );

    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_err(), 'Should fail with zero supply');
}
