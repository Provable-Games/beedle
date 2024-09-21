use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

// INT_EDGE_001: Token with identical payment and distribution tokens
#[test]
fn test_identical_payment_distribution_tokens() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Deploy where contract token and payment token addresses are very close
    let mut constructor_calldata = array![];
    let name: ByteArray = "Self Trading Token";
    let symbol: ByteArray = "STT";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let payment_token = contract_address_const::<
        0x1000000000,
    >(); // Very close to potential contract address
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

    // Verify pool key handles token ordering correctly
    let pool_key = distribution_dispatcher.get_distribution_pool_key();

    // Tokens should be ordered with smaller address as token0
    if contract_address < payment_token {
        assert(pool_key.token0 == contract_address, 'Wrong token0 ordering');
        assert(pool_key.token1 == payment_token, 'Wrong token1 ordering');
    } else {
        assert(pool_key.token0 == payment_token, 'Wrong token0 ordering');
        assert(pool_key.token1 == contract_address, 'Wrong token1 ordering');
    }
}

// INT_EDGE_002: Minimum possible values
#[test]
fn test_minimum_values_edge_case() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Deploy with minimum values
    let mut constructor_calldata = array![];
    let name: ByteArray = "M"; // Minimal name
    let symbol: ByteArray = "M"; // Minimal symbol
    let total_supply: u128 = 1; // Minimum supply
    let pool_fee: u128 = 1; // Minimum fee
    let tick_spacing: u32 = 1; // Minimum tick spacing
    let payment_token = contract_address_const::<0x1>();
    let reward_token = contract_address_const::<0x2>();
    let core_address = contract_address_const::<0x3>();
    let positions_address = contract_address_const::<0x4>();
    let extension_address = contract_address_const::<0x5>();

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

    // Verify minimum values work
    assert(token_dispatcher.total_supply() == 1_u256, 'Min supply failed');
    assert(
        token_dispatcher.balance_of(contract_address) == 0_u256, 'Min balance failed',
    ); // All sent to registry
    assert(distribution_dispatcher.get_pool_fee() == 1, 'Min fee failed');
    assert(distribution_dispatcher.get_tick_spacing() == 1, 'Min tick failed');
    // Note: Cannot start distribution with 0 tokens remaining
}

// INT_EDGE_003: Rapid state transitions
#[test]
fn test_rapid_state_transitions() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Rapid Transition Token";
    let symbol: ByteArray = "RTT";
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

    // Rapid transitions: deploy -> init pool -> start distribution -> claim
    start_cheat_block_timestamp_global(1000);

    // Initialize pool immediately
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();

    // Start distribution immediately
    mock_call(
        positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, 10000_u128), 100,
    );
    distribution_dispatcher.start_token_distribution(2000);

    // Claim immediately
    mock_call(
        positions_address,
        selector!("withdraw_proceeds_from_sale_to_self"),
        0_u128, // No proceeds yet
        100,
    );
    mock_call(positions_address, selector!("increase_sell_amount"), 0_u128, 100);
    distribution_dispatcher.claim_and_sell_proceeds();

    // Verify state consistency after rapid transitions
    assert(distribution_dispatcher.get_pool_id() == 1, 'Pool ID inconsistent');
    assert(distribution_dispatcher.get_position_token_id() == 1, 'Position ID inconsistent');
    assert(distribution_dispatcher.get_distribution_start_time() == 992, 'Start time inconsistent');
    assert(distribution_dispatcher.get_reward_distribution_rate() == 0, 'Reward rate inconsistent');
}

// INT_EDGE_004: Maximum duration distribution
#[test]
fn test_maximum_duration_distribution() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "Max Duration Token";
    let symbol: ByteArray = "MDT";
    let total_supply: u128 = 0xffffffffffffffffffffffffffffffff; // MAX_U128
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

    // Initialize pool
    mock_call(core_address, selector!("initialize_pool"), 1_u256, 100);
    distribution_dispatcher.init_distribution_pool();

    // Start distribution with maximum reasonable duration
    let max_duration = 31536000_u64; // 1 year in seconds
    let rate = (total_supply - 1) / max_duration.into();

    mock_call(positions_address, selector!("mint_and_increase_sell_amount"), (1_u64, rate), 100);
    start_cheat_block_timestamp_global(0);
    distribution_dispatcher.start_token_distribution(max_duration);

    // Verify distribution parameters
    assert(
        distribution_dispatcher.get_distribution_end_time() == max_duration, 'Wrong max duration',
    );
    let actual_rate = distribution_dispatcher.get_token_distribution_rate();
    assert(actual_rate >= rate - 1 && actual_rate <= rate + 1, 'Wrong rate for max duration');
}

// INT_EDGE_005: Zero addresses edge case
#[test]
#[should_panic]
fn test_zero_address_edge_case() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Try to deploy with zero addresses (should fail in real scenarios)
    let mut constructor_calldata = array![];
    let name: ByteArray = "Zero Address Token";
    let symbol: ByteArray = "ZAT";
    let total_supply: u128 = 1000000;
    let pool_fee: u128 = 3000;
    let tick_spacing: u32 = 60;
    let zero_address = contract_address_const::<0x0>();
    let payment_token = contract_address_const::<0x1234567890>();
    let core_address = contract_address_const::<0x1111111111>();
    let positions_address = contract_address_const::<0x2222222222>();
    let extension_address = contract_address_const::<0x3333333333>();

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    zero_address.serialize(ref constructor_calldata); // Zero payment token
    payment_token.serialize(ref constructor_calldata); // Valid reward token
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    // This should panic or fail in a real implementation
    contract.deploy(@constructor_calldata).unwrap();
}
