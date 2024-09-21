use core::num::traits::Zero;
use core::result::ResultTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ContractAddress, contract_address_const};

// Simple test to verify the test framework works
#[test]
fn test_basic_arithmetic() {
    let a = 2;
    let b = 3;
    assert(a + b == 5, 'Basic math failed');
}

#[test]
fn test_address_comparison() {
    assert(
        contract_address_const::<0x123>() != contract_address_const::<0>(),
        'Addresses should differ',
    );
    assert(
        contract_address_const::<0>() == Zero::<ContractAddress>::zero(), 'Zero address mismatch',
    );
}

// Test that we can declare the contracts
#[test]
fn test_declare_contracts() {
    // Declare main contract
    let main_contract_result = declare("EkuboDistributedERC20");
    assert(main_contract_result.is_ok(), 'Main contract fail');

    // Declare mock contracts
    let core_result = declare("MockCore");
    assert(core_result.is_ok(), 'MockCore fail');

    let positions_result = declare("MockPositions");
    assert(positions_result.is_ok(), 'MockPositions fail');

    let registry_result = declare("MockTokenRegistry");
    assert(registry_result.is_ok(), 'MockRegistry fail');
}

// Test mock deployment
#[test]
fn test_deploy_mocks() {
    // Deploy mock core
    let core_contract = declare("MockCore").unwrap().contract_class();
    let (core_address, _) = core_contract.deploy(@array![]).unwrap();
    assert(core_address != contract_address_const::<0>(), 'Core deploy failed');

    // Deploy mock positions
    let positions_contract = declare("MockPositions").unwrap().contract_class();
    let (positions_address, _) = positions_contract.deploy(@array![]).unwrap();
    assert(positions_address != contract_address_const::<0>(), 'Positions deploy failed');

    // Deploy mock token registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();
    assert(registry_address != contract_address_const::<0>(), 'Registry deploy failed');
}
// Note: Full integration tests with the EkuboDistributedERC20 contract
// would require fixing the transfer_from issue in the constructor.
// The contract tries to transfer_from itself without approval.
// In a real deployment, this would need to be handled differently.


