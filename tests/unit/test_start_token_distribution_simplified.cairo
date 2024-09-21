use gerc20::interfaces::{IEkuboDistributedERC20DispatcherTrait};
use snforge_std::{start_cheat_block_timestamp_global};
use super::super::common::test_helpers::{
    default_deployment_params, deploy_contract_with_params, mock_ekubo_core,
};

// UT_START_DIST_001: Successfully start distribution
#[test]
fn test_start_distribution_success() {
    let (_contract_address, dispatcher, _token_dispatcher) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize pool first
    mock_ekubo_core(1_u256);
    dispatcher.init_distribution_pool();

    // Set timestamp
    start_cheat_block_timestamp_global(1000);

    // Start distribution
    dispatcher.start_token_distribution(11080); // end_time = 1000 + 10080

    // Verify state
    assert(dispatcher.get_position_token_id() == 1, 'Position ID should be 1');
    // Start time should be rounded down to nearest 16 (1000 / 16 * 16 = 992)
    assert(dispatcher.get_distribution_start_time() == 992, 'Wrong start time');
    assert(dispatcher.get_distribution_end_time() == 11080, 'Wrong end time');
    assert(dispatcher.get_token_distribution_rate() > 0, 'Distribution rate should be set');
}

// UT_START_DIST_002: Start distribution with different timestamps
#[test]
fn test_start_distribution_various_times() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize pool
    mock_ekubo_core(2_u256);
    dispatcher.init_distribution_pool();

    // Test with timestamp 5000
    start_cheat_block_timestamp_global(5000);

    dispatcher.start_token_distribution(25160); // 5000 + 20160

    // Start time should be rounded down to nearest 16 (5000 / 16 * 16 = 4992)
    assert(dispatcher.get_distribution_start_time() == 4992, 'Wrong start time');
    assert(dispatcher.get_distribution_end_time() == 25160, 'Wrong end time');
}

// UT_START_DIST_REVERT_001: Cannot start before pool initialization
#[test]
#[should_panic(expected: ('dist pool not initialized',))]
fn test_start_distribution_no_pool() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Try to start distribution without pool init
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(2000);
}

// UT_START_DIST_REVERT_002: Cannot start distribution twice
#[test]
#[should_panic(expected: ('distribution already started',))]
fn test_start_distribution_twice() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize and start first distribution
    mock_ekubo_core(3_u256);
    dispatcher.init_distribution_pool();

    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(11080);

    // Try to start again
    dispatcher.start_token_distribution(20000);
}

// UT_START_DIST_REVERT_003: End time too soon
#[test]
#[should_panic]
fn test_start_distribution_end_too_soon() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize pool
    mock_ekubo_core(4_u256);
    dispatcher.init_distribution_pool();

    // Try with end time equal to start time (will cause division by zero)
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(992); // Same as rounded start time
}

// UT_START_DIST_003: Test with maximum distribution period
#[test]
fn test_start_distribution_max_period() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize pool
    mock_ekubo_core(5_u256);
    dispatcher.init_distribution_pool();

    // Set up for maximum period
    start_cheat_block_timestamp_global(1000);

    let max_end_time = 1000 + 2592000; // 30 days
    dispatcher.start_token_distribution(max_end_time);

    assert(dispatcher.get_distribution_end_time() == max_end_time, 'Wrong end time');
    assert(dispatcher.get_position_token_id() == 1, 'Position should be created');
}
