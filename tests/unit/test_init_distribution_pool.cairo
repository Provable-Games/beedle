use gerc20::interfaces::{IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};
use starknet::{contract_address_const};
use super::super::common::test_helpers::{
    default_deployment_params, deploy_contract_with_params, mock_ekubo_core, start_caller,
    stop_caller,
};

// UT_INIT_POOL_001: First successful initialization
#[test]
fn test_init_pool_first_successful() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Mock the core dispatcher's initialize_pool to return a pool ID
    mock_ekubo_core(1_u256);

    // Initialize the pool
    dispatcher.init_distribution_pool();

    // Verify pool ID was set
    assert(dispatcher.get_pool_id() == 1, 'Pool ID should be 1');
}

// UT_INIT_POOL_REVERT_001: Pool already initialized
#[test]
#[should_panic(expected: ('pool already initialized',))]
fn test_init_pool_already_initialized() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Mock the core dispatcher's initialize_pool
    mock_ekubo_core(1_u256);

    // Initialize the pool
    dispatcher.init_distribution_pool();

    // Try to initialize again - should panic
    dispatcher.init_distribution_pool();
}

// UT_INIT_POOL_002: Pool initialization with high ID
#[test]
fn test_init_pool_with_high_id() {
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Mock the core dispatcher to return a high pool ID
    mock_ekubo_core(999999_u256);

    // Initialize the pool
    dispatcher.init_distribution_pool();

    // Verify high pool ID was set correctly
    assert(dispatcher.get_pool_id() == 999999, 'Pool ID should be 999999');
}

// New test: Verify initialization can be called by any address
#[test]
fn test_init_pool_any_caller() {
    let (contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Mock the core dispatcher
    mock_ekubo_core(1_u256);

    // Test with different caller address
    let random_caller = contract_address_const::<0x99999>();
    start_caller(contract_address, random_caller);

    // Should succeed regardless of caller
    dispatcher.init_distribution_pool();

    stop_caller(contract_address);

    // Verify pool was initialized
    assert(dispatcher.get_pool_id() == 1, 'Pool should be initialized');
}

// Test using custom deployment parameters
#[test]
fn test_init_pool_custom_params() {
    // Create custom params by calling default and building new
    let default_params = default_deployment_params();
    let params = super::super::common::test_helpers::DeploymentParams {
        name: "Test Token",
        symbol: "TEST",
        total_supply: 10000000, // 10M tokens
        pool_fee: 10000, // 1% fee
        tick_spacing: default_params.tick_spacing,
    };

    let (_contract_address, dispatcher, token_dispatcher) = deploy_contract_with_params(params);

    // Verify custom parameters
    assert(token_dispatcher.total_supply() == 10000000_u256, 'Wrong total supply');
    assert(dispatcher.get_pool_fee() == 10000, 'Wrong pool fee');

    // Mock and initialize
    mock_ekubo_core(42_u256);
    dispatcher.init_distribution_pool();

    assert(dispatcher.get_pool_id() == 42, 'Wrong pool ID');
}
