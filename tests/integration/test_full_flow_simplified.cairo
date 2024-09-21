use gerc20::interfaces::{IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};
use snforge_std::{start_cheat_block_timestamp_global};
use super::super::common::test_helpers::{
    advance_time, default_deployment_params, deploy_contract_with_params, mock_ekubo_core,
};

// INT_FLOW_001: Complete deployment to distribution flow - simplified
#[test]
fn test_complete_deployment_to_distribution_flow_simplified() {
    // Step 1: Deploy contract with default parameters
    let (contract_address, distribution_dispatcher, token_dispatcher) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Verify initial state
    assert(token_dispatcher.total_supply() == 1000000_u256, 'Wrong total supply');
    assert(token_dispatcher.balance_of(contract_address) == 999999_u256, 'Wrong contract balance');
    assert(distribution_dispatcher.get_pool_id() == 0, 'Pool should not be initialized');

    // Step 2: Initialize pool using helper
    mock_ekubo_core(1_u256);
    distribution_dispatcher.init_distribution_pool();
    assert(distribution_dispatcher.get_pool_id() == 1, 'Pool not initialized');

    // Step 3: Start distribution
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(2000);

    // Verify distribution started
    assert(distribution_dispatcher.get_position_token_id() == 1, 'Position not created');
    assert(distribution_dispatcher.get_distribution_start_time() == 992, 'Wrong start time');
    assert(distribution_dispatcher.get_distribution_end_time() == 2000, 'Wrong end time');
    assert(distribution_dispatcher.get_token_distribution_rate() > 0, 'Rate should be set');

    // Step 4: Claim proceeds
    // Note: In a real scenario, this would update the reward rate
    // but our mock setup may not fully simulate the reward token purchase
    distribution_dispatcher.claim_and_sell_proceeds();
}

// INT_FLOW_002: Multiple claim cycles - simplified
#[test]
fn test_multiple_claim_cycles_simplified() {
    // Setup contract with default params (we'll use the default 1M supply)
    let (_contract_address, dispatcher, _) = deploy_contract_with_params(
        default_deployment_params(),
    );

    // Initialize and start distribution
    mock_ekubo_core(2_u256);
    dispatcher.init_distribution_pool();

    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(100000); // Long distribution period

    // Perform multiple claim cycles
    let mut i = 0;
    loop {
        if i == 3 {
            break;
        }

        // Advance time between claims
        advance_time(1000);

        // Claim proceeds - in real scenario this would accumulate rewards
        dispatcher.claim_and_sell_proceeds();

        i += 1;
    };
}

