use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher, IEkuboDistributedERC20DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
};
use starknet::contract_address_const;

#[test]
fn test_constructor_works_after_fix() {
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

    // Deploy the contract
    let deploy_result = contract.deploy(@constructor_calldata);
    assert(deploy_result.is_ok(), 'Deploy should succeed');

    let (contract_address, _) = deploy_result.unwrap();

    // Verify deployment was successful
    let token_dispatcher = IERC20Dispatcher { contract_address };
    let distribution_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    // Verify ERC20 properties
    assert(token_dispatcher.total_supply() == 1000000_u256, 'Wrong total supply');

    // Verify token was minted to contract (minus 1 sent to registry)
    assert(token_dispatcher.balance_of(contract_address) == 999999_u256, 'Wrong contract balance');

    // Verify registry received 1 token
    assert(token_dispatcher.balance_of(registry_address) == 1_u256, 'Wrong registry balance');

    // Verify stored parameters
    assert(distribution_dispatcher.get_payment_token() == payment_token, 'Wrong payment token');
    assert(distribution_dispatcher.get_reward_token() == reward_token, 'Wrong reward token');
    assert(distribution_dispatcher.get_pool_fee() == 3000, 'Wrong pool fee');
    assert(distribution_dispatcher.get_tick_spacing() == 60, 'Wrong tick spacing');
    assert(distribution_dispatcher.get_extension_address() == extension_address, 'Wrong extension');

    // Verify initial state
    assert(distribution_dispatcher.get_pool_id() == 0, 'Pool ID should be 0');
    assert(distribution_dispatcher.get_position_token_id() == 0, 'Position ID should be 0');
    assert(distribution_dispatcher.get_distribution_start_time() == 0, 'Start time should be 0');
    assert(distribution_dispatcher.get_distribution_end_time() == 0, 'End time should be 0');
    assert(distribution_dispatcher.get_deployed_at() != 0, 'Deployed at should not be 0');
}
