use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

// Helper to setup contract with distribution
fn setup_distribution() -> IEkuboDistributedERC20Dispatcher {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Time Test Token";
    let symbol: ByteArray = "TTT";
    let total_supply: u128 = 86400000; // 86.4M tokens (1000 per second for 24 hours)
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
    let dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Initialize pool
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    dispatcher
}

// INT_TIME_001: Distribution over different time periods
#[test]
fn test_distribution_time_periods() {
    let dispatcher = setup_distribution();

    // Test 1 hour distribution
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 23999_u128), // (86.4M - 1) / 3600 seconds
        100,
    );
    start_cheat_block_timestamp_global(0);
    dispatcher.start_token_distribution(3600); // 1 hour

    assert(dispatcher.get_distribution_end_time() == 3600, 'Wrong 1hr end time');
    let rate = dispatcher.get_token_distribution_rate();
    assert(rate >= 23998 && rate <= 24000, 'Wrong 1hr rate');

    // Test 24 hour distribution
    let dispatcher2 = setup_distribution();
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 999_u128), // (86.4M - 1) / 86400 seconds
        100,
    );
    start_cheat_block_timestamp_global(0);
    dispatcher2.start_token_distribution(86400); // 24 hours

    assert(dispatcher2.get_distribution_end_time() == 86400, 'Wrong 24hr end time');
    let rate2 = dispatcher2.get_token_distribution_rate();
    assert(rate2 >= 999 && rate2 <= 1000, 'Wrong 24hr rate');
}

// INT_TIME_002: Time progression effects on claims
#[test]
fn test_time_progression_claims() {
    let dispatcher = setup_distribution();

    // Start 10 hour distribution
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 2399_u128), // (86.4M - 1) / 36000 seconds
        100,
    );
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(37000); // 10 hours from t=1000

    // Claim after 1 hour
    start_cheat_block_timestamp_global(4600); // 1 hour later
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("withdraw_proceeds_from_sale_to_self"),
        2400_u128 * 3600, // 1 hour worth of proceeds
        100,
    );
    mock_call(
        contract_address_const::<0x2222222222>(), selector!("increase_sell_amount"), 100_u128, 100,
    );
    dispatcher.claim_and_sell_proceeds();
    assert(dispatcher.get_reward_distribution_rate() == 100, 'Wrong rate after 1hr');

    // Claim after 5 more hours
    start_cheat_block_timestamp_global(22600); // 5 hours later
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("withdraw_proceeds_from_sale_to_self"),
        2400_u128 * 18000, // 5 hours worth
        100,
    );
    mock_call(
        contract_address_const::<0x2222222222>(), selector!("increase_sell_amount"), 500_u128, 100,
    );
    dispatcher.claim_and_sell_proceeds();
    assert(dispatcher.get_reward_distribution_rate() == 600, 'Wrong rate after 6hr'); // 100 + 500
}

// INT_TIME_003: Time rounding edge cases
#[test]
fn test_time_rounding_edge_cases() {
    let dispatcher = setup_distribution();

    // Test with unaligned start time
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );
    start_cheat_block_timestamp_global(999); // Not aligned to 16
    dispatcher.start_token_distribution(2015); // End time

    // Start time should round down to 992 (999/16*16)
    assert(dispatcher.get_distribution_start_time() == 992, 'Wrong rounded start time');
    assert(dispatcher.get_distribution_end_time() == 2015, 'Wrong end time');

    // Test with aligned start time
    let dispatcher2 = setup_distribution();
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );
    start_cheat_block_timestamp_global(1024); // Aligned to 16
    dispatcher2.start_token_distribution(2048);

    assert(dispatcher2.get_distribution_start_time() == 1024, 'Wrong aligned start time');
}

// INT_TIME_004: Long running distribution simulation
#[test]
fn test_long_running_distribution() {
    let dispatcher = setup_distribution();

    // Start 30 day distribution
    let thirty_days = 2592000_u64; // 30 * 24 * 60 * 60
    let rate = 86399999_u128 / thirty_days.into(); // Total supply - 1 / duration

    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, rate),
        100,
    );
    start_cheat_block_timestamp_global(1000000);
    dispatcher.start_token_distribution(1000000 + thirty_days);

    // Verify distribution parameters
    assert(dispatcher.get_distribution_end_time() == 1000000 + thirty_days, 'Wrong 30d end time');
    let actual_rate = dispatcher.get_token_distribution_rate();
    assert(actual_rate >= rate - 1 && actual_rate <= rate + 1, 'Wrong 30d rate');

    // Simulate weekly claims
    let week = 604800_u64;
    let mut current_time = 1000000_u64;

    // Week 1 claim
    current_time += week;
    start_cheat_block_timestamp_global(current_time);
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("withdraw_proceeds_from_sale_to_self"),
        1000000_u128, // Arbitrary proceeds
        100,
    );
    mock_call(
        contract_address_const::<0x2222222222>(), selector!("increase_sell_amount"), 1000_u128, 100,
    );
    dispatcher.claim_and_sell_proceeds();
    assert(dispatcher.get_reward_distribution_rate() == 1000, 'Wrong week 1 rate');

    // Week 2 claim
    current_time += week;
    start_cheat_block_timestamp_global(current_time);
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("withdraw_proceeds_from_sale_to_self"),
        2000000_u128,
        100,
    );
    mock_call(
        contract_address_const::<0x2222222222>(), selector!("increase_sell_amount"), 2000_u128, 100,
    );
    dispatcher.claim_and_sell_proceeds();
    assert(dispatcher.get_reward_distribution_rate() == 3000, 'Wrong week 2 rate'); // 1000 + 2000
}
