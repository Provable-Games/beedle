use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

// INT_FLOW_001: Complete deployment to distribution flow
#[test]
fn test_complete_deployment_to_distribution_flow() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Step 1: Deploy contract with mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Integration Test Token";
    let symbol: ByteArray = "ITT";
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

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address };

    // Verify initial state
    assert(token_dispatcher.total_supply() == 1000000_u256, 'Wrong total supply');
    assert(token_dispatcher.balance_of(contract_address) == 999999_u256, 'Wrong contract balance');
    assert(distribution_dispatcher.get_pool_id() == 0, 'Pool should not be initialized');

    // Step 2: Initialize pool
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();
    assert(distribution_dispatcher.get_pool_id() == 1, 'Pool not initialized');

    // Step 3: Start distribution
    mock_call(
        positions_address,
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 992_u128), // 999999 / 1008 ≈ 992
        100,
    );
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(2000);

    // Verify distribution started
    assert(distribution_dispatcher.get_position_token_id() == 1, 'Position not created');
    assert(distribution_dispatcher.get_distribution_start_time() == 992, 'Wrong start time');
    assert(distribution_dispatcher.get_distribution_end_time() == 2000, 'Wrong end time');
    assert(distribution_dispatcher.get_token_distribution_rate() == 992, 'Wrong distribution rate');

    // Step 4: Claim proceeds
    mock_call(positions_address, selector!("withdraw_proceeds_from_sale_to_self"), 50000_u128, 100);
    mock_call(positions_address, selector!("increase_sell_amount"), 100_u128, 100);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Verify claim
    assert(
        distribution_dispatcher.get_reward_distribution_rate() == 100, 'Reward rate not updated',
    );
}

// INT_FLOW_002: Multiple claim cycles
#[test]
fn test_multiple_claim_cycles() {
    // Setup contract with distribution started
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Multi Claim Token";
    let symbol: ByteArray = "MCT";
    let total_supply: u128 = 10000000; // 10M tokens
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

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Initialize and start
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();

    mock_call(
        positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, 10000_u128), 100,
    );
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(1000000); // Long distribution

    // First claim
    mock_call(
        positions_address, selector!("withdraw_proceeds_from_sale_to_self"), 100000_u128, 100,
    );
    mock_call(positions_address, selector!("increase_sell_amount"), 1000_u128, 100);
    distribution_dispatcher.claim_and_sell_proceeds();
    assert(distribution_dispatcher.get_reward_distribution_rate() == 1000, 'First claim failed');

    // Second claim with different values
    mock_call(
        positions_address, selector!("withdraw_proceeds_from_sale_to_self"), 200000_u128, 100,
    );
    mock_call(positions_address, selector!("increase_sell_amount"), 2000_u128, 100);
    distribution_dispatcher.claim_and_sell_proceeds();
    assert(
        distribution_dispatcher.get_reward_distribution_rate() == 3000, 'Second claim failed',
    ); // 1000 + 2000

    // Third claim with zero proceeds
    mock_call(positions_address, selector!("withdraw_proceeds_from_sale_to_self"), 0_u128, 100);
    mock_call(positions_address, selector!("increase_sell_amount"), 0_u128, 100);
    distribution_dispatcher.claim_and_sell_proceeds();
    assert(
        distribution_dispatcher.get_reward_distribution_rate() == 3000, 'Third claim failed',
    ); // Still 3000
}

// INT_FLOW_003: Pool initialization with different token orderings
#[test]
fn test_pool_initialization_token_ordering() {
    // Test when contract address < payment token
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // First scenario: payment token has higher address
    let mut constructor_calldata = array![];
    let name: ByteArray = "Token Order Test";
    let symbol: ByteArray = "TOT";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let payment_token = contract_address_const::<0xFFFFFFFFFFFFFFFF>(); // Very high address
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

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Get pool key and verify ordering
    let pool_key = distribution_dispatcher.get_distribution_pool_key();
    // Verify tokens are properly ordered (smaller address first)
    if contract_address < payment_token {
        assert(pool_key.token0 == contract_address, 'Wrong token0 ordering');
        assert(pool_key.token1 == payment_token, 'Wrong token1 ordering');
    } else {
        assert(pool_key.token0 == payment_token, 'Wrong token0 ordering');
        assert(pool_key.token1 == contract_address, 'Wrong token1 ordering');
    }

    // Initialize pool
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();
    assert(distribution_dispatcher.get_pool_id() == 1, 'Pool init failed');
}
