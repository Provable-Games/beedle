use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::IERC20Dispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
};
use starknet::{ContractAddress};
use super::super::common::test_helpers::{
    core_address, extension_address, mock_ekubo_core, mock_positions_claim, mock_positions_mint,
    payment_token, positions_address, reward_token,
};

// Helper to deploy contract with mocks
fn setup_contract_with_distribution() -> (
    ContractAddress, IEkuboDistributedERC20Dispatcher, IERC20Dispatcher,
) {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Prepare constructor parameters
    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    payment_token().serialize(ref constructor_calldata);
    reward_token().serialize(ref constructor_calldata);
    core_address().serialize(ref constructor_calldata);
    positions_address().serialize(ref constructor_calldata);
    extension_address().serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let deploy_result = contract.deploy(@constructor_calldata);
    let (contract_address, _) = deploy_result.unwrap();

    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address };

    // Initialize pool using helper
    mock_ekubo_core(1_u256);
    distribution_dispatcher.init_distribution_pool();

    // Start distribution using helper
    mock_positions_mint(1_u64, 1000_u128);
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(2000);

    (contract_address, distribution_dispatcher, token_dispatcher)
}

// UT_CLAIM_001: Successfully claim proceeds from completed sale
#[test]
fn test_claim_and_sell_proceeds_success() {
    let (_, distribution_dispatcher, _) = setup_contract_with_distribution();

    // Use helper to mock positions claim
    mock_positions_claim(50000_u128, 100_u128);

    // Claim proceeds
    distribution_dispatcher.claim_and_sell_proceeds();

    // Verify reward distribution rate was updated
    assert(distribution_dispatcher.get_reward_distribution_rate() == 100, 'Wrong reward rate');
}

// UT_CLAIM_002: Claim proceeds updates reward distribution rate correctly
#[test]
fn test_claim_proceeds_updates_reward_rate() {
    let (_, distribution_dispatcher, _) = setup_contract_with_distribution();

    // First claim using helper
    mock_positions_claim(50000_u128, 50_u128);
    distribution_dispatcher.claim_and_sell_proceeds();
    assert(distribution_dispatcher.get_reward_distribution_rate() == 50, 'Wrong initial rate');

    // Second claim with different proceeds using helper
    mock_positions_claim(100000_u128, 75_u128);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Rate should accumulate
    assert(distribution_dispatcher.get_reward_distribution_rate() == 125, 'Wrong cumulative rate');
}

// UT_CLAIM_003: Claim with zero proceeds
#[test]
fn test_claim_zero_proceeds() {
    let (_, distribution_dispatcher, _) = setup_contract_with_distribution();

    // Mock zero proceeds using helper
    mock_positions_claim(0_u128, 0_u128);

    // Claim proceeds
    distribution_dispatcher.claim_and_sell_proceeds();

    // Reward rate should remain 0
    assert(distribution_dispatcher.get_reward_distribution_rate() == 0, 'Rate should be 0');
}

// UT_CLAIM_004: Multiple claims accumulate correctly
#[test]
fn test_multiple_claims_accumulate() {
    let (_, distribution_dispatcher, _) = setup_contract_with_distribution();

    // First claim
    mock_positions_claim(10000_u128, 10_u128);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Second claim
    mock_positions_claim(20000_u128, 20_u128);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Third claim
    mock_positions_claim(30000_u128, 30_u128);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Total rate should be 10 + 20 + 30 = 60
    assert(distribution_dispatcher.get_reward_distribution_rate() == 60, 'Wrong total rate');
}

// UT_CLAIM_REVERT_001: Cannot claim before pool is initialized
#[test]
#[should_panic(expected: ('dist pool not initialized',))]
fn test_claim_before_distribution_starts() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy with minimal setup
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    payment_token().serialize(ref constructor_calldata);
    reward_token().serialize(ref constructor_calldata);
    core_address().serialize(ref constructor_calldata);
    positions_address().serialize(ref constructor_calldata);
    extension_address().serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Try to claim without starting distribution
    distribution_dispatcher.claim_and_sell_proceeds();
}
