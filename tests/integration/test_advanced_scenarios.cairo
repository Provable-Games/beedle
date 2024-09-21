use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

// INT_ADV_001: Complex multi-step scenarios
#[test]
fn test_complex_multi_step_scenario() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Deploy with large supply
    let mut constructor_calldata = array![];
    let name: ByteArray = "Advanced Test Token";
    let symbol: ByteArray = "ATT";
    let total_supply: u128 = 1000000000; // 1 billion
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
    let _token_dispatcher = IERC20Dispatcher { contract_address };

    // Step 1: Initialize pool with specific ID
    mock_call(core_address, selector!("initialize_pool"), 999_u256, 100);
    distribution_dispatcher.init_distribution_pool();
    assert(distribution_dispatcher.get_pool_id() == 999, 'Pool ID mismatch');

    // Step 2: Start long-term distribution
    mock_call(
        positions_address,
        selector!("mint_and_increase_sell_amount"),
        (42_u64, 100_u128), // Slow rate
        100,
    );
    start_cheat_block_timestamp_global(10000);
    distribution_dispatcher.start_token_distribution(10000000); // ~115 days

    // Step 3: Multiple claims at different intervals
    let claim_times = array![
        (50000_u64, 1000000_u128, 50_u128), // After ~11 hours
        (100000_u64, 2000000_u128, 100_u128), // After ~1 day
        (500000_u64, 10000000_u128, 500_u128), // After ~5 days
        (1000000_u64, 20000000_u128, 1000_u128) // After ~11 days
    ];

    let mut total_reward_rate = 0_u128;
    let mut i = 0;
    loop {
        if i >= claim_times.len() {
            break;
        }

        let (time, proceeds, rate_increase) = *claim_times.at(i);

        start_cheat_block_timestamp_global(time);

        mock_call(
            positions_address, selector!("withdraw_proceeds_from_sale_to_self"), proceeds, 100,
        );
        mock_call(positions_address, selector!("increase_sell_amount"), rate_increase, 100);

        distribution_dispatcher.claim_and_sell_proceeds();

        total_reward_rate += rate_increase; // Accumulate rates
        assert(
            distribution_dispatcher.get_reward_distribution_rate() == total_reward_rate,
            'Wrong reward rate',
        );

        i += 1;
    };
}

// INT_ADV_002: High frequency claims
#[test]
fn test_high_frequency_claims() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "High Freq Token";
    let symbol: ByteArray = "HFT";
    let total_supply: u128 = 100000000;
    let pool_fee: u128 = 500; // Low fee for high volume
    let tick_spacing: u32 = 10; // Small tick spacing
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
        positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, 1000_u128), 100,
    );
    start_cheat_block_timestamp_global(0);
    distribution_dispatcher.start_token_distribution(100000); // ~27 hours

    // Perform 20 claims in rapid succession
    let mut current_time = 1000_u64;
    let mut i = 0;
    let mut cumulative_rate = 0_u128;
    loop {
        if i >= 20 {
            break;
        }

        current_time += 100; // Claim every 100 seconds
        start_cheat_block_timestamp_global(current_time);

        let proceeds = (i + 1) * 1000_u128;
        let rate = (i + 1) * 10_u128;
        cumulative_rate += rate;

        mock_call(
            positions_address, selector!("withdraw_proceeds_from_sale_to_self"), proceeds, 100,
        );
        mock_call(positions_address, selector!("increase_sell_amount"), rate, 100);

        distribution_dispatcher.claim_and_sell_proceeds();
        assert(
            distribution_dispatcher.get_reward_distribution_rate() == cumulative_rate,
            'Wrong HF rate',
        );

        i += 1;
    };
}

// INT_ADV_003: Edge case token amounts
#[test]
fn test_edge_case_token_amounts() {
    // Test with minimum supply
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Edge Case Token";
    let symbol: ByteArray = "ECT";
    let total_supply: u128 = 2; // Minimum meaningful supply (1 goes to registry, 1 to distribute)
    let pool_fee: u128 = 10000; // High fee
    let tick_spacing: u32 = 200; // Large tick spacing
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

    // Verify balances
    assert(token_dispatcher.total_supply() == 2, 'Wrong total supply');
    assert(token_dispatcher.balance_of(contract_address) == 1, 'Wrong contract balance');
    assert(token_dispatcher.balance_of(registry_address) == 1, 'Wrong registry balance');

    // Initialize pool
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();

    // Start distribution with only 1 token
    mock_call(
        positions_address,
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 0_u128), // Rate should be 0 (1 token / long duration rounds to 0)
        100,
    );
    start_cheat_block_timestamp_global(1000);
    distribution_dispatcher.start_token_distribution(1000000);

    // Verify rate is 0
    assert(distribution_dispatcher.get_token_distribution_rate() == 0, 'Rate should be 0');
}

// INT_ADV_004: Reward token same as payment token
#[test]
fn test_same_payment_reward_token() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let same_token = contract_address_const::<0xABCDEF>();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Same Token Test";
    let symbol: ByteArray = "STT";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let core_address = contract_address_const::<0x1111111111>();
    let positions_address = contract_address_const::<0x2222222222>();
    let extension_address = contract_address_const::<0x3333333333>();

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    same_token.serialize(ref constructor_calldata); // payment_token
    same_token.serialize(ref constructor_calldata); // reward_token (same)
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify both tokens are the same
    assert(distribution_dispatcher.get_payment_token() == same_token, 'Wrong payment token');
    assert(distribution_dispatcher.get_reward_token() == same_token, 'Wrong reward token');
    // When payment and reward tokens are the same, the contract should handle this case
// The actual pool key would be determined by the token ordering in Ekubo
}
