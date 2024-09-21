// Common test helpers and mock patterns for Starknet Foundry tests
use snforge_std::{mock_call};
use starknet::{ContractAddress, contract_address_const};

// Mock Ekubo core contract for pool initialization
pub fn mock_ekubo_core(pool_id: u256) {
    mock_call(contract_address_const::<0x1111111111>(), selector!("initialize_pool"), pool_id, 100);
}

// Mock positions contract for a full distribution cycle
pub fn mock_positions_full_cycle(
    position_id: u64, initial_rate: u128, proceeds: u128, reward_rate: u128,
) {
    let positions = contract_address_const::<0x2222222222>();

    // Mock mint_and_increase_sell_amount
    mock_call(
        positions, selector!("mint_and_increase_sell_amount"), (position_id, initial_rate), 100,
    );

    // Mock withdraw_proceeds_from_sale_to_self
    mock_call(positions, selector!("withdraw_proceeds_from_sale_to_self"), proceeds, 100);

    // Mock increase_sell_amount
    mock_call(positions, selector!("increase_sell_amount"), reward_rate, 100);
}

// Mock positions contract for simple mint
pub fn mock_positions_mint(position_id: u64, rate: u128) {
    mock_call(
        contract_address_const::<0x2222222222>(),
        selector!("mint_and_increase_sell_amount"),
        (position_id, rate),
        100,
    );
}

// Mock positions contract for claiming proceeds
pub fn mock_positions_claim(proceeds: u128, new_rate: u128) {
    let positions = contract_address_const::<0x2222222222>();

    mock_call(positions, selector!("withdraw_proceeds_from_sale_to_self"), proceeds, 100);

    mock_call(positions, selector!("increase_sell_amount"), new_rate, 100);
}

// Setup token balance mocks
pub fn setup_token_balances(token: ContractAddress, holder: ContractAddress, amount: u256) {
    // Mock the balanceOf call
    mock_call(token, selector!("balanceOf"), amount, 1);

    // Mock the transfer call to always succeed
    mock_call(token, selector!("transfer"), true, 1);
}

// Common test addresses
pub fn payment_token() -> ContractAddress {
    contract_address_const::<0x1234567890>()
}

pub fn reward_token() -> ContractAddress {
    contract_address_const::<0x9876543210>()
}

pub fn core_address() -> ContractAddress {
    contract_address_const::<0x1111111111>()
}

pub fn positions_address() -> ContractAddress {
    contract_address_const::<0x2222222222>()
}

pub fn extension_address() -> ContractAddress {
    contract_address_const::<0x3333333333>()
}

// Deployment builder pattern
use core::result::ResultTrait;
use gerc20::interfaces::{IEkuboDistributedERC20Dispatcher};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[derive(Drop)]
pub struct DeploymentParams {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub total_supply: u128,
    pub pool_fee: u128,
    pub tick_spacing: u32,
}

pub fn default_deployment_params() -> DeploymentParams {
    DeploymentParams {
        name: "Test Token", symbol: "TEST", total_supply: 1000000, pool_fee: 3000, tick_spacing: 60,
    }
}

pub fn deploy_contract_with_params(
    params: DeploymentParams,
) -> (ContractAddress, IEkuboDistributedERC20Dispatcher, IERC20Dispatcher) {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Deploy mock registry
    let registry_contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Deploy mock positions contract
    let positions_contract = declare("MockPositions").unwrap().contract_class();
    let (positions_address, _) = positions_contract.deploy(@array![]).unwrap();

    // Serialize parameters
    let mut constructor_calldata = array![];
    params.name.serialize(ref constructor_calldata);
    params.symbol.serialize(ref constructor_calldata);
    params.total_supply.serialize(ref constructor_calldata);
    params.pool_fee.serialize(ref constructor_calldata);
    params.tick_spacing.serialize(ref constructor_calldata);
    payment_token().serialize(ref constructor_calldata);
    reward_token().serialize(ref constructor_calldata);
    core_address().serialize(ref constructor_calldata);
    positions_address.serialize(ref constructor_calldata);
    extension_address().serialize(ref constructor_calldata);
    registry_address.serialize(ref constructor_calldata);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dist_dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address };

    (contract_address, dist_dispatcher, token_dispatcher)
}

// Helper for testing with specific caller
use snforge_std::{
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
};

// Start caller address cheat for a specific contract
pub fn start_caller(target: ContractAddress, caller: ContractAddress) {
    start_cheat_caller_address(target, caller);
}

// Stop caller address cheat for a specific contract
pub fn stop_caller(target: ContractAddress) {
    stop_cheat_caller_address(target);
}

// Helper to advance time in tests
pub fn advance_time(seconds: u64) {
    let current = starknet::get_block_timestamp();
    start_cheat_block_timestamp_global(current + seconds);
}

// Event testing helper
use snforge_std::{spy_events};

// Helper to spy on events from a specific contract
pub fn spy_events_from(contract_address: ContractAddress) -> snforge_std::EventSpy {
    let mut spy = spy_events();
    spy
}
