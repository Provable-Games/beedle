use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::contract_address_const;

// FUZZ_CONSTRUCTOR_001: Fuzz test constructor with random valid parameters
#[test]
#[fuzzer(runs: 50)]
fn test_constructor_fuzz_valid_params(total_supply: u128, pool_fee: u128, tick_spacing: u32) {
    // Skip invalid values
    if total_supply == 0 || pool_fee == 0 || tick_spacing == 0 {
        return;
    }

    // Bound values to reasonable ranges
    let total_supply = total_supply % 1000000000000_u128 + 1; // 1 to 1 trillion
    let pool_fee = pool_fee % 10000_u128 + 1; // 1 to 10000
    let tick_spacing = tick_spacing % 200_u32 + 1; // 1 to 200

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let mut constructor_calldata = array![];
    let name_ba: ByteArray = "Test Token";
    let symbol_ba: ByteArray = "TEST";
    let payment_token = contract_address_const::<0x1234567890>();
    let reward_token = contract_address_const::<0x9876543210>();
    let core_address = contract_address_const::<0x1111111111>();
    let positions_address = contract_address_const::<0x2222222222>();
    let extension_address = contract_address_const::<0x3333333333>();

    name_ba.serialize(ref constructor_calldata);
    symbol_ba.serialize(ref constructor_calldata);
    total_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    payment_token.serialize(ref constructor_calldata);
    reward_token.serialize(ref constructor_calldata);
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');

    let (contract_address, _) = deploy_result.unwrap();
    let token_dispatcher = IERC20Dispatcher { contract_address };
    let dist_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify deployment
    assert(token_dispatcher.total_supply() == total_supply.into(), 'Wrong total supply');
    assert(dist_dispatcher.get_pool_fee() == pool_fee, 'Wrong pool fee');
    assert(dist_dispatcher.get_tick_spacing() == tick_spacing, 'Wrong tick spacing');
}

// Test constructor with boundary values
#[test]
#[fuzzer(runs: 10)]
fn test_constructor_fuzz_boundaries(total_supply: u128) {
    // Test with extreme values including boundaries
    let test_supply = if total_supply < 100 {
        1_u128 // Test minimum
    } else if total_supply > 340282366920938463463374607431768211400_u128 {
        340282366920938463463374607431768211455_u128 // MAX_U128
    } else {
        total_supply
    };

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
    test_supply.serialize(ref constructor_calldata);
    pool_fee.serialize(ref constructor_calldata);
    tick_spacing.serialize(ref constructor_calldata);
    payment_token.serialize(ref constructor_calldata);
    reward_token.serialize(ref constructor_calldata);
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');

    let (contract_address, _) = deploy_result.unwrap();
    let token_dispatcher = IERC20Dispatcher { contract_address };

    // Verify deployment
    assert(token_dispatcher.total_supply() == test_supply.into(), 'Wrong total supply');

    // For supply of 1, all tokens go to registry
    if test_supply == 1 {
        assert(token_dispatcher.balance_of(contract_address) == 0, 'Wrong balance for supply=1');
    } else {
        assert(
            token_dispatcher.balance_of(contract_address) == (test_supply - 1).into(),
            'Wrong contract balance',
        );
    }
}

// Test with random addresses
#[test]
#[fuzzer(runs: 20)]
fn test_constructor_fuzz_addresses(
    payment_seed: felt252,
    reward_seed: felt252,
    core_seed: felt252,
    positions_seed: felt252,
    extension_seed: felt252,
) {
    // Skip if any seed is zero
    if payment_seed == 0
        || reward_seed == 0
        || core_seed == 0
        || positions_seed == 0
        || extension_seed == 0 {
        return;
    }

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Generate addresses from seeds by using them directly as contract addresses
    let payment_token: starknet::ContractAddress = payment_seed.try_into().unwrap();
    let reward_token: starknet::ContractAddress = reward_seed.try_into().unwrap();
    let core_address: starknet::ContractAddress = core_seed.try_into().unwrap();
    let positions_address: starknet::ContractAddress = positions_seed.try_into().unwrap();
    let extension_address: starknet::ContractAddress = extension_seed.try_into().unwrap();

    // Deploy mock registry
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
    payment_token.serialize(ref constructor_calldata);
    reward_token.serialize(ref constructor_calldata);
    core_address.serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address.serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');

    let (contract_address, _) = deploy_result.unwrap();
    let dist_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify addresses were stored correctly
    assert(dist_dispatcher.get_payment_token() == payment_token, 'Wrong payment token');
    assert(dist_dispatcher.get_reward_token() == reward_token, 'Wrong reward token');
    assert(dist_dispatcher.get_extension_address() == extension_address, 'Wrong extension');
}

// Combined fuzz test with all parameters
#[test]
#[fuzzer(runs: 30)]
fn test_constructor_fuzz_combined(
    total_supply: u128,
    pool_fee: u128,
    tick_spacing: u32,
    payment_seed: felt252,
    reward_seed: felt252,
) {
    // Skip invalid values
    if total_supply == 0
        || pool_fee == 0
        || tick_spacing == 0
        || payment_seed == 0
        || reward_seed == 0 {
        return;
    }

    // Bound values
    let total_supply = total_supply % 1000000000000_u128 + 1;
    let pool_fee = pool_fee % 10000_u128 + 1;
    let tick_spacing = tick_spacing % 200_u32 + 1;

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Use fixed names for simplicity (fuzzing ByteArray is complex)
    let name: ByteArray = "Fuzz Token";
    let symbol: ByteArray = "FUZZ";

    // Generate addresses from seeds
    let payment_token: starknet::ContractAddress = payment_seed.try_into().unwrap();
    let reward_token: starknet::ContractAddress = reward_seed.try_into().unwrap();
    let core_address = contract_address_const::<0x1111111111>();
    let positions_address = contract_address_const::<0x2222222222>();
    let extension_address = contract_address_const::<0x3333333333>();

    let mut constructor_calldata = array![];
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

    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');

    let (contract_address, _) = deploy_result.unwrap();
    let token_dispatcher = IERC20Dispatcher { contract_address };
    let dist_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify core parameters
    assert(token_dispatcher.total_supply() == total_supply.into(), 'Wrong total supply');
    assert(dist_dispatcher.get_pool_fee() == pool_fee, 'Wrong pool fee');
    assert(dist_dispatcher.get_tick_spacing() == tick_spacing, 'Wrong tick spacing');
    assert(dist_dispatcher.get_payment_token() == payment_token, 'Wrong payment token');
    assert(dist_dispatcher.get_reward_token() == reward_token, 'Wrong reward token');
}
