use core::result::ResultTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ContractAddress, contract_address_const};

// Helper to prepare constructor calldata with mock registry deployment
fn prepare_constructor_calldata_with_registry(
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
) -> (Array<felt252>, ContractAddress) {
    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

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
    (calldata, registry_address)
}

// UT_CONSTRUCTOR_BOUNDARY_001: Empty name and symbol
#[test]
fn test_constructor_boundary_empty_name_symbol() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let (calldata, _) = prepare_constructor_calldata_with_registry(
        "", // Empty name
        "", // Empty symbol
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
    );

    // Deploy should succeed now that the transfer_from issue is fixed
    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
}

// UT_CONSTRUCTOR_BOUNDARY_002: Very long name and symbol
#[test]
fn test_constructor_boundary_long_name_symbol() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Create very long strings (ByteArray can handle arbitrary length)
    let long_name =
        "This is a very long token name that exceeds typical lengths used in production environments and tests the limits of ByteArray handling in Cairo";
    let long_symbol = "VERYLONGSYMBOL1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    let (calldata, _) = prepare_constructor_calldata_with_registry(
        long_name,
        long_symbol,
        1000000,
        3000,
        60,
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
    );

    // Deploy should succeed now that the transfer_from issue is fixed
    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
}

// UT_CONSTRUCTOR_BOUNDARY_003: Zero pool_fee and tick_spacing
#[test]
fn test_constructor_boundary_zero_pool_fee_tick_spacing() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let (calldata, _) = prepare_constructor_calldata_with_registry(
        "Test Token",
        "TEST",
        1000000,
        0, // Zero pool fee
        0, // Zero tick spacing
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
    );

    // Deploy should succeed now that the transfer_from issue is fixed
    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
}

// Additional boundary test: Maximum values for pool_fee and tick_spacing
#[test]
fn test_constructor_boundary_max_pool_fee_tick_spacing() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let (calldata, _) = prepare_constructor_calldata_with_registry(
        "Test Token",
        "TEST",
        1000000,
        0xffffffffffffffffffffffffffffffff, // MAX_U128 for pool fee
        0xffffffff, // MAX_U32 for tick spacing
        contract_address_const::<0x1234567890>(),
        contract_address_const::<0x9876543210>(),
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
    );

    // Deploy should succeed now that the transfer_from issue is fixed
    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
}

// Boundary test: Same payment and reward token
#[test]
fn test_constructor_boundary_same_payment_reward_token() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    let same_token = contract_address_const::<0x1234567890>();

    let (calldata, _) = prepare_constructor_calldata_with_registry(
        "Test Token",
        "TEST",
        1000000,
        3000,
        60,
        same_token, // Same as reward token
        same_token, // Same as payment token
        contract_address_const::<0x1111111111>(),
        contract_address_const::<0x2222222222>(),
        contract_address_const::<0x3333333333>(),
    );

    // Deploy should succeed now that the transfer_from issue is fixed
    let deploy_result = contract.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');
}
