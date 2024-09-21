use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
};
use starknet::{ContractAddress, contract_address_const};

// Test addresses
fn PAYMENT_TOKEN() -> ContractAddress {
    contract_address_const::<0x1234567890>()
}

fn REWARD_TOKEN() -> ContractAddress {
    contract_address_const::<0x9876543210>()
}

fn CORE_ADDRESS() -> ContractAddress {
    contract_address_const::<0x1111111111>()
}

fn POSITIONS_ADDRESS() -> ContractAddress {
    contract_address_const::<0x2222222222>()
}

fn EXTENSION_ADDRESS() -> ContractAddress {
    contract_address_const::<0x3333333333>()
}

// Helper to deploy with standard parameters
fn deploy_with_params(
    name: ByteArray,
    symbol: ByteArray,
    total_supply: u128,
    pool_fee: u128,
    tick_spacing: u32,
    payment_token: ContractAddress,
    reward_token: ContractAddress,
    core_address: ContractAddress,
    positions_address: ContractAddress,
    extension_address: ContractAddress,
) -> ContractAddress {
    // Deploy mock registry first
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

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

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

// UT_CONSTRUCTOR_001: Valid parameters with standard values
#[test]
fn test_constructor_valid_standard_params() {
    start_cheat_block_timestamp_global(1000);

    let contract_address = deploy_with_params(
        "Test Token",
        "TEST",
        1000000_u128,
        3000_u128,
        60_u32,
        PAYMENT_TOKEN(),
        REWARD_TOKEN(),
        CORE_ADDRESS(),
        POSITIONS_ADDRESS(),
        EXTENSION_ADDRESS(),
    );

    let token_dispatcher = IERC20Dispatcher { contract_address };
    let metadata_dispatcher = IERC20MetadataDispatcher { contract_address };
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify ERC20 properties
    assert(metadata_dispatcher.name() == "Test Token", 'Wrong name');
    assert(metadata_dispatcher.symbol() == "TEST", 'Wrong symbol');
    assert(token_dispatcher.total_supply() == 1000000_u256, 'Wrong total supply');

    // Verify we have the total supply minus 1 for the registry
    assert(token_dispatcher.balance_of(contract_address) == 999999_u256, 'Wrong contract balance');

    // Verify stored parameters
    assert(distribution_dispatcher.get_payment_token() == PAYMENT_TOKEN(), 'Wrong payment token');
    assert(distribution_dispatcher.get_reward_token() == REWARD_TOKEN(), 'Wrong reward token');
    assert(distribution_dispatcher.get_pool_fee() == 3000, 'Wrong pool fee');
    assert(distribution_dispatcher.get_tick_spacing() == 60, 'Wrong tick spacing');
    assert(
        distribution_dispatcher.get_extension_address() == EXTENSION_ADDRESS(), 'Wrong extension',
    );

    // Verify initial state
    assert(distribution_dispatcher.get_pool_id() == 0, 'Pool ID should be 0');
    assert(distribution_dispatcher.get_position_token_id() == 0, 'Position ID should be 0');
    assert(distribution_dispatcher.get_distribution_start_time() == 0, 'Start time should be 0');
    assert(distribution_dispatcher.get_distribution_end_time() == 0, 'End time should be 0');
    assert(distribution_dispatcher.get_deployed_at() == 1000, 'Deployed at should be 1000');
}

// UT_CONSTRUCTOR_002: Minimum valid total_supply (1)
#[test]
fn test_constructor_minimum_supply() {
    let contract_address = deploy_with_params(
        "Min Supply Token",
        "MIN",
        1_u128, // Minimum supply
        3000_u128,
        60_u32,
        PAYMENT_TOKEN(),
        REWARD_TOKEN(),
        CORE_ADDRESS(),
        POSITIONS_ADDRESS(),
        EXTENSION_ADDRESS(),
    );

    let token_dispatcher = IERC20Dispatcher { contract_address };

    // Verify total supply
    assert(token_dispatcher.total_supply() == 1_u256, 'Wrong total supply');

    // Contract should have 0 tokens (1 was sent to registry)
    assert(token_dispatcher.balance_of(contract_address) == 0_u256, 'Wrong contract balance');
}

// UT_CONSTRUCTOR_003: Maximum valid total_supply (MAX_U128)
#[test]
fn test_constructor_maximum_supply() {
    let max_supply = 0xffffffffffffffffffffffffffffffff_u128; // MAX_U128

    let contract_address = deploy_with_params(
        "Max Supply Token",
        "MAX",
        max_supply,
        3000_u128,
        60_u32,
        PAYMENT_TOKEN(),
        REWARD_TOKEN(),
        CORE_ADDRESS(),
        POSITIONS_ADDRESS(),
        EXTENSION_ADDRESS(),
    );

    let token_dispatcher = IERC20Dispatcher { contract_address };

    // Verify total supply
    assert(token_dispatcher.total_supply() == max_supply.into(), 'Wrong total supply');

    // Contract should have max_supply - 1
    assert(
        token_dispatcher.balance_of(contract_address) == (max_supply - 1).into(),
        'Wrong contract balance',
    );
}
