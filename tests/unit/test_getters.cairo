use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_block_timestamp_global,
};
use starknet::{ContractAddress, contract_address_const};

// Helper to deploy contract
fn setup_contract() -> (ContractAddress, IEkuboDistributedERC20Dispatcher) {
    // Set a block timestamp before deployment
    start_cheat_block_timestamp_global(1000);

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

    let deploy_result = contract.deploy(@constructor_calldata);
    let (contract_address, _) = deploy_result.unwrap();

    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    (contract_address, distribution_dispatcher)
}

// UT_GETTERS_001: All getters return correct values after deployment
#[test]
fn test_getters_after_deployment() {
    let (_contract_address, dispatcher) = setup_contract();

    // Test all getters
    assert(
        dispatcher.get_payment_token() == contract_address_const::<0x1234567890>(),
        'Wrong payment token',
    );
    assert(
        dispatcher.get_reward_token() == contract_address_const::<0x9876543210>(),
        'Wrong reward token',
    );
    assert(dispatcher.get_pool_fee() == 3000, 'Wrong pool fee');
    assert(dispatcher.get_tick_spacing() == 60, 'Wrong tick spacing');
    assert(
        dispatcher.get_extension_address() == contract_address_const::<0x3333333333>(),
        'Wrong extension',
    );
    assert(dispatcher.get_deployed_at() != 0, 'Deployed at should not be 0');

    // Test initial state getters
    assert(dispatcher.get_pool_id() == 0, 'Pool ID should be 0');
    assert(dispatcher.get_position_token_id() == 0, 'Position ID should be 0');
    assert(dispatcher.get_distribution_start_time() == 0, 'Start time should be 0');
    assert(dispatcher.get_distribution_end_time() == 0, 'End time should be 0');
    assert(dispatcher.get_token_distribution_rate() == 0, 'Token rate should be 0');
    assert(dispatcher.get_reward_distribution_rate() == 0, 'Reward rate should be 0');
}

// UT_GETTERS_002: Pool key generation
#[test]
fn test_get_distribution_pool_key() {
    let (contract_address, dispatcher) = setup_contract();

    let pool_key = dispatcher.get_distribution_pool_key();

    // Verify pool key fields
    assert(pool_key.fee == 3000, 'Wrong pool fee');
    assert(pool_key.tick_spacing == 60, 'Wrong tick spacing');
    assert(pool_key.extension == contract_address_const::<0x3333333333>(), 'Wrong extension');

    // Verify token ordering (contract address vs payment token)
    let payment_token = contract_address_const::<0x1234567890>();
    if contract_address < payment_token {
        assert(pool_key.token0 == contract_address, 'Wrong token0');
        assert(pool_key.token1 == payment_token, 'Wrong token1');
    } else {
        assert(pool_key.token0 == payment_token, 'Wrong token0');
        assert(pool_key.token1 == contract_address, 'Wrong token1');
    }
}

// UT_GETTERS_003: Getters after state changes
#[test]
fn test_getters_after_state_changes() {
    let (_contract_address, dispatcher) = setup_contract();

    // Initialize pool
    mock_call(
        contract_address_const::<0x1111111111>(),
        selector!("initialize_pool"),
        1_u256, // Return pool ID 1
        100,
    );
    dispatcher.init_distribution_pool();

    // Verify pool ID was set
    assert(dispatcher.get_pool_id() == 1, 'Pool ID should be 1');

    // Start distribution
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (1_u64, 1000_u128),
        100,
    );
    start_cheat_block_timestamp_global(1000);
    dispatcher.start_token_distribution(2000);

    // Verify distribution parameters were set
    assert(dispatcher.get_distribution_start_time() == 992, 'Wrong start time');
    assert(dispatcher.get_distribution_end_time() == 2000, 'Wrong end time');
    assert(dispatcher.get_position_token_id() == 1, 'Wrong position token ID');
    assert(dispatcher.get_token_distribution_rate() > 0, 'Token rate should be > 0');
}

// Note: get_reward_pool_key() doesn't exist in the interface
// The contract only has get_distribution_pool_key() for the distribution pool

// UT_GETTERS_005: Verify deployed_at timestamp
#[test]
fn test_deployed_at_timestamp() {
    let (_contract_address, dispatcher) = setup_contract();

    // Verify deployed_at matches the timestamp set in setup_contract (1000)
    assert(dispatcher.get_deployed_at() == 1000, 'Wrong deployed_at timestamp');
}
