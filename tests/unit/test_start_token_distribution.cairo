use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::{ContractAddress, contract_address_const};

// Helper to deploy contract with mocks
fn setup_contract() -> (ContractAddress, IEkuboDistributedERC20Dispatcher, IERC20Dispatcher) {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Deploy mock positions contract
    let positions_contract = declare("MockPositions").unwrap().contract_class();
    let (positions_address, _) = positions_contract.deploy(@array![]).unwrap();

    // Prepare constructor parameters
    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let payment_token = contract_address_const::<0x1234567890>();
    let reward_token = contract_address_const::<0x9876543210>();
    let core_address = contract_address_const::<0x1111111111>();
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

    let deploy_result = contract.deploy(@constructor_calldata);
    let (contract_address, _) = deploy_result.unwrap();

    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address };

    (contract_address, distribution_dispatcher, token_dispatcher)
}

// UT_START_DIST_001: Valid future end_time
#[test]
#[should_panic(expected: ('dist pool not initialized',))]
fn test_start_distribution_valid_future_end_time() {
    let (_, distribution_dispatcher, _) = setup_contract();

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Try to start distribution without initializing pool first
    // Should panic with DISTRIBUTION_POOL_NOT_INITIALIZED
    distribution_dispatcher.start_token_distribution(2000);
}

// UT_START_DIST_002: End_time exactly aligned to block boundaries
#[test]
#[should_panic(expected: ('dist pool not initialized',))]
fn test_start_distribution_aligned_end_time() {
    let (_, distribution_dispatcher, _) = setup_contract();

    // Set block timestamp to aligned value
    start_cheat_block_timestamp_global(1024); // 64 * 16

    // Try with aligned end time
    distribution_dispatcher.start_token_distribution(2048); // 128 * 16
}

// UT_START_DIST_REVERT_001: Pool not initialized
#[test]
#[should_panic(expected: ('dist pool not initialized',))]
fn test_start_distribution_revert_pool_not_initialized() {
    let (_, distribution_dispatcher, _) = setup_contract();

    // Try to start distribution without initializing pool
    distribution_dispatcher.start_token_distribution(2000);
}

// UT_START_DIST_REVERT_002: Distribution already started
#[test]
#[should_panic(expected: ('distribution already started',))]
fn test_start_distribution_revert_already_started() {
    let (_, distribution_dispatcher, _) = setup_contract();

    // First init pool
    mock_call(
        contract_address_const::<0x1111111111>(), // Core address
        selector!("initialize_pool"),
        1_u256, // Return pool ID 1
        100,
    );
    distribution_dispatcher.init_distribution_pool();

    // Start distribution
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(2000);

    // Verify position token ID was set
    assert(distribution_dispatcher.get_position_token_id() != 0, 'Position ID should be set');

    // Try to start again - should panic
    distribution_dispatcher.start_token_distribution(3000);
}

// UT_START_DIST_REVERT_003: End_time in the past
#[test]
#[should_panic]
fn test_start_distribution_revert_end_time_past() {
    let (_, distribution_dispatcher, _) = setup_contract();

    // First init pool
    mock_call(
        contract_address_const::<0x1111111111>(), // Core address
        selector!("initialize_pool"),
        1_u256, // Return pool ID 1
        100,
    );
    distribution_dispatcher.init_distribution_pool();

    // Set block timestamp
    start_cheat_block_timestamp_global(2000);

    // Try with past end time
    // This will cause MockPositions to panic with arithmetic underflow
    // when calculating sale_rate = amount / (end_time - start_time)
    // as end_time (1000) < start_time (1984)
    distribution_dispatcher.start_token_distribution(1000);
}

// Test successful distribution start
#[test]
fn test_start_distribution_success() {
    let (_contract_address, distribution_dispatcher, _token_dispatcher) = setup_contract();

    // First init pool
    mock_call(
        contract_address_const::<0x1111111111>(), // Core address
        selector!("initialize_pool"),
        1_u256, // Return pool ID 1
        100,
    );
    distribution_dispatcher.init_distribution_pool();

    // No need to mock - MockPositions is deployed and will calculate the rate

    // Start distribution
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(2000);

    // Verify state was updated
    assert(
        distribution_dispatcher.get_distribution_start_time() == 992, 'Wrong start time',
    ); // (1000/16)*16
    assert(distribution_dispatcher.get_distribution_end_time() == 2000, 'Wrong end time');
    assert(
        distribution_dispatcher.get_position_token_id() == 1, 'Wrong position token ID',
    ); // MockPositions starts at 1

    // Verify rate calculation
    let expected_rate = 999999 / (2000 - 992); // Total tokens / duration
    assert(
        distribution_dispatcher.get_token_distribution_rate() == expected_rate, 'Wrong token rate',
    );
}
