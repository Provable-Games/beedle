use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::{contract_address_const};

// Helper to setup contract for time tests
fn setup_time_test_contract() -> IEkuboDistributedERC20Dispatcher {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
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
    IEkuboDistributedERC20Dispatcher { contract_address }
}

// FUZZ_TIME_001: Fuzz test time rounding behaviors
#[test]
#[fuzzer(runs: 80)]
fn test_time_rounding_fuzz(block_time: u64, time_offset: u64) {
    // Skip zero values
    if block_time == 0 || time_offset == 0 {
        return;
    }

    // Bound values to reasonable ranges
    let block_time = block_time % 1000000; // 0 to 1M
    let time_offset = time_offset % 10000 + 16; // 16 to 10,016
    let end_time = block_time + time_offset;

    let dispatcher = setup_time_test_contract();

    // Initialize pool
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    // Mock positions
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );

    // Start distribution with test timestamp
    start_cheat_block_timestamp_global(block_time);
    dispatcher.start_token_distribution(end_time);

    // Verify start time was rounded correctly
    let actual_start = dispatcher.get_distribution_start_time();
    let expected_start = (block_time / 16) * 16; // Round down to multiple of 16
    assert(actual_start == expected_start, 'Wrong start time rounding');

    // Verify end time is stored correctly
    assert(dispatcher.get_distribution_end_time() == end_time, 'Wrong end time');
}

// Test edge cases for time calculations
#[test]
#[fuzzer(runs: 20)]
fn test_time_edge_cases_fuzz(large_time: u64) {
    // Skip zero
    if large_time == 0 {
        return;
    }

    // Focus on large timestamps
    let max_time = if large_time > 0xFFFFFFFF {
        large_time % 0xFFFFFFFFFFFF // Cap at 48-bit max
    } else {
        large_time + 0xFFFFFF // Ensure it's reasonably large
    };

    // Only test if we have room for a valid distribution
    if max_time < 2000 {
        return;
    }

    let dispatcher = setup_time_test_contract();

    // Initialize pool
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    // Mock positions
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );

    // Test with large timestamp
    start_cheat_block_timestamp_global(max_time - 1000);
    dispatcher.start_token_distribution(max_time);

    // Verify times are handled correctly
    assert(dispatcher.get_distribution_end_time() == max_time, 'Wrong max end time');
    assert(dispatcher.get_distribution_start_time() < max_time, 'Start >= end time');
}

// Test rate calculations with various time durations
#[test]
#[fuzzer(runs: 60)]
fn test_rate_calculation_fuzz(duration_seed: u64, supply_seed: u128) {
    // Skip zero values
    if duration_seed == 0 || supply_seed == 0 {
        return;
    }

    // Generate duration from seed (biased towards common values)
    let duration = if duration_seed % 10 < 3 {
        // 30% chance of very short duration
        (duration_seed % 100) + 16
    } else if duration_seed % 10 < 7 {
        // 40% chance of medium duration
        (duration_seed % 86400) + 100
    } else {
        // 30% chance of long duration
        (duration_seed % 2592000) + 86400
    };

    // Generate supply from seed
    let total_supply = (supply_seed % 1000000000000_u128) + 1; // 1 to 1 trillion

    let _dispatcher = setup_time_test_contract();

    // Deploy contract with specific supply
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
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

    // Calculate expected rate
    let distributable = if total_supply > 1 {
        total_supply - 1
    } else {
        0
    };
    let expected_rate = distributable / duration.into();

    // Mock positions with expected rate
    mock_call(
        positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, expected_rate), 100,
    );

    // Start distribution
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(1000 + duration);

    // Verify rate calculation
    let actual_rate = dispatcher.get_token_distribution_rate();
    // Allow for rounding
    let lower_bound = if expected_rate > 0 {
        expected_rate - 1
    } else {
        0
    };
    assert(
        actual_rate >= lower_bound && actual_rate <= expected_rate + 1, 'Wrong rate calculation',
    );
}

// Combined fuzzing: time alignment and rate calculations
#[test]
#[fuzzer(runs: 40)]
fn test_time_and_rate_combined_fuzz(
    block_time: u64, duration: u64, total_supply: u128, alignment_offset: u8,
) {
    // Skip invalid values
    if block_time == 0 || duration == 0 || total_supply == 0 {
        return;
    }

    // Bound values
    let block_time = block_time % 100000 + 1000; // 1K to 101K
    let duration = duration % 100000 + 100; // 100 to 100,100
    let total_supply = total_supply % 1000000000_u128 + 1000; // 1K to 1B

    // Add alignment offset to test various alignments
    let block_time = block_time + (alignment_offset % 16).into();
    let end_time = block_time + duration;

    // Deploy contract with specific supply
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";
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

    // Calculate expected values
    let expected_start = (block_time / 16) * 16;
    let actual_duration = end_time - expected_start;
    let distributable = if total_supply > 1 {
        total_supply - 1
    } else {
        0
    };
    let expected_rate = if actual_duration > 0 {
        distributable / actual_duration.into()
    } else {
        0
    };

    // Mock positions
    mock_call(
        positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, expected_rate), 100,
    );

    // Start distribution
    start_cheat_block_timestamp_global(block_time);
    dispatcher.start_token_distribution(end_time);

    // Verify time alignment
    assert(dispatcher.get_distribution_start_time() == expected_start, 'Wrong time alignment');
    assert(dispatcher.get_distribution_end_time() == end_time, 'Wrong end time');

    // Verify rate calculation
    let actual_rate = dispatcher.get_token_distribution_rate();
    let lower_bound = if expected_rate > 0 {
        expected_rate - 1
    } else {
        0
    };
    assert(
        actual_rate >= lower_bound && actual_rate <= expected_rate + 1, 'Wrong rate with alignment',
    );
}
