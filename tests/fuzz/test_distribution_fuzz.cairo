use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

// Helper to setup contract with custom parameters
fn setup_contract_with_supply(total_supply: u128) -> IEkuboDistributedERC20Dispatcher {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
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
    IEkuboDistributedERC20Dispatcher { contract_address }
}

// FUZZ_DISTRIBUTION_001: Fuzz test distribution with various time ranges
#[test]
#[fuzzer(runs: 100)]
fn test_distribution_time_ranges_fuzz(start_time: u64, duration: u64) {
    // Skip invalid values
    if start_time == 0 || duration == 0 {
        return;
    }

    // Bound values to reasonable ranges
    let start_time = start_time % 1000000 + 1000; // 1000 to 1,001,000
    let duration = duration % 1000000 + 100; // 100 to 1,000,100 seconds
    let end_time = start_time + duration;

    // Setup contract with fixed supply
    let test_dispatcher = setup_contract_with_supply(1000000000); // 1 billion

    // Initialize pool
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    test_dispatcher.init_distribution_pool();

    // Mock positions response with calculated rate
    let rate = 999999999_u128 / duration.into(); // (total_supply - 1) / duration
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, rate),
        100,
    );

    // Start distribution
    start_cheat_block_timestamp_global(start_time);
    test_dispatcher.start_token_distribution(end_time);

    // Verify distribution parameters
    assert(test_dispatcher.get_distribution_end_time() == end_time, 'Wrong end time');
    let actual_rate = test_dispatcher.get_token_distribution_rate();
    // Allow for rounding differences
    let lower_bound = if rate > 0 {
        rate - 1
    } else {
        0
    };
    assert(actual_rate >= lower_bound && actual_rate <= rate + 1, 'Wrong rate');
}

// FUZZ_DISTRIBUTION_002: Test with different total supplies
#[test]
#[fuzzer(runs: 50)]
fn test_distribution_supply_variations_fuzz(total_supply: u128) {
    // Skip zero supply
    if total_supply == 0 {
        return;
    }

    // Bound to reasonable range
    let total_supply = total_supply % 1000000000000_u128 + 1; // 1 to 1 trillion

    // Deploy contract with specific supply
    let dispatcher = setup_contract_with_supply(total_supply);

    // Initialize pool
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    // Start distribution
    let start_time = 1000_u64;
    let end_time = 10000_u64;
    let duration = end_time - start_time;
    let expected_rate = if total_supply > 1 {
        (total_supply - 1) / duration.into()
    } else {
        0_u128 // If supply is 1, all goes to registry
    };

    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, expected_rate),
        100,
    );

    start_cheat_block_timestamp_global(start_time);
    dispatcher.start_token_distribution(end_time);

    // Verify rate calculation
    let actual_rate = dispatcher.get_token_distribution_rate();
    let lower_bound = if expected_rate > 0 {
        expected_rate - 1
    } else {
        0
    };
    assert(actual_rate >= lower_bound && actual_rate <= expected_rate + 1, 'Wrong rate for supply');
}

// FUZZ_DISTRIBUTION_003: Test claim proceeds with various amounts
#[test]
#[fuzzer(runs: 40)]
fn test_claim_proceeds_amounts_fuzz(proceeds: u128, iterations: u8) {
    // Bound values
    let proceeds = proceeds % 10000000_u128; // 0 to 10 million
    let iterations = iterations % 5 + 1; // 1 to 5 iterations

    let dispatcher = setup_contract_with_supply(1000000000);

    // Initialize and start distribution
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(10000);

    // Test multiple claims with the same proceeds amount
    let mut cumulative_rate = 0_u128;
    let mut i = 0_u8;
    loop {
        if i >= iterations {
            break;
        }

        let new_rate_increase = if proceeds > 0 {
            proceeds / 100
        } else {
            0
        };
        cumulative_rate += new_rate_increase;

        // Mock claim responses
        mock_call(
            contract_address_const::<0x2222222222>(),
            selector!("withdraw_proceeds_from_sale_to_self"),
            proceeds,
            100,
        );
        mock_call(
            contract_address_const::<0x2222222222>(),
            selector!("increase_sell_amount"),
            new_rate_increase,
            100,
        );

        // Claim proceeds
        dispatcher.claim_and_sell_proceeds();

        // Verify reward rate was updated (cumulative)
        assert(dispatcher.get_reward_distribution_rate() == cumulative_rate, 'Wrong reward rate');

        i += 1;
    };
}

// FUZZ_DISTRIBUTION_004: Combined fuzzing - time, supply, and proceeds
#[test]
#[fuzzer(runs: 30)]
fn test_distribution_combined_fuzz(
    total_supply: u128, start_time: u64, duration: u64, proceeds: u128,
) {
    // Skip invalid values
    if total_supply == 0 || start_time == 0 || duration == 0 {
        return;
    }

    // Bound values
    let total_supply = total_supply % 1000000000_u128 + 1000; // 1K to 1B
    let start_time = start_time % 100000 + 1000; // 1K to 101K
    let duration = duration % 100000 + 100; // 100 to 100,100
    let end_time = start_time + duration;
    let proceeds = proceeds % 1000000_u128; // 0 to 1M

    // Deploy contract
    let dispatcher = setup_contract_with_supply(total_supply);

    // Initialize pool
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), 1_u256, 100);
    dispatcher.init_distribution_pool();

    // Calculate and mock distribution rate
    let expected_rate = if total_supply > 1 {
        (total_supply - 1) / duration.into()
    } else {
        0_u128
    };

    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, expected_rate),
        100,
    );

    // Start distribution
    start_cheat_block_timestamp_global(start_time);
    dispatcher.start_token_distribution(end_time);

    // Verify initial state
    assert(dispatcher.get_distribution_end_time() == end_time, 'Wrong end time');
    let actual_rate = dispatcher.get_token_distribution_rate();
    let lower_bound = if expected_rate > 0 {
        expected_rate - 1
    } else {
        0
    };
    assert(actual_rate >= lower_bound && actual_rate <= expected_rate + 1, 'Wrong initial rate');

    // Test claiming proceeds
    let reward_rate = if proceeds > 0 {
        proceeds / 100
    } else {
        0
    };

    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("withdraw_proceeds_from_sale_to_self"),
        proceeds,
        100,
    );
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("increase_sell_amount"),
        reward_rate,
        100,
    );

    dispatcher.claim_and_sell_proceeds();
    assert(dispatcher.get_reward_distribution_rate() == reward_rate, 'Wrong reward rate');
}
