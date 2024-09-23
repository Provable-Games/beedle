use starknet::{ContractAddress};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use gerc20::interfaces::IEkuboDistributedERC20SafeDispatcher;
use gerc20::interfaces::IEkuboDistributedERC20SafeDispatcherTrait;
use gerc20::interfaces::IEkuboDistributedERC20Dispatcher;
use gerc20::interfaces::IEkuboDistributedERC20DispatcherTrait;
use openzeppelin_utils::serde::SerializedAppend;
use gerc20::tests::mock_erc20::DualCaseERC20Mock;
use gerc20::tests::mock_positions::MockPositions;
use gerc20::tests::mock_twamm::MockTWAMM;
use gerc20::tests::mock_core::MockCore;

const TOTAL_SUPPLY: u128 = 1000000;
const EMISSION_DURATION: u64 = 86400;
const PROCEEDS_DISTRIBUTION_DURATION: u64 = 3600;

fn NAME() -> ByteArray {
    "RevivalPotion"
}

fn SYMBOL() -> ByteArray {
    "REVIVE"
}

fn deploy_erc20(
    contract_class: ContractClass,
    name: ByteArray,
    symbol: ByteArray,
    supply: u256,
    owner: ContractAddress
) -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(supply);
    calldata.append_serde(owner);

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address: contract_address }
}

fn deploy_contract() -> ContractAddress {
    // Declare and deploy the mock Core contract
    let mock_core_contract = declare("MockCore").unwrap().contract_class();
    let (core_address, _) = mock_core_contract.deploy(@[]).unwrap();

    // Declare and deploy the mock Positions contract
    let mock_positions_contract = declare("MockPositions").unwrap().contract_class();
    let (positions_address, _) = mock_positions_contract.deploy(@[]).unwrap();

    // Declare and deploy the mock Extension contract
    let mock_extension_contract = declare("MockTWAMM").unwrap().contract_class();
    let (extension_address, _) = mock_extension_contract.deploy(@[]).unwrap();

    // Declare and deploy the mock ERC20 contract
    let erc20_class_hash = declare("DualCaseERC20Mock").unwrap();
    let payment_token = deploy_erc20(
        erc20_class_hash, "LORDS", "LORDS", 10000000000000000000000000000000000000000, CALLER()
    );
    let purchase_token = deploy_erc20(
        erc20_class_hash, "SAUVAGE", "SVG", 10000000000000000000000000000000000000000, CALLER()
    );

    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(TOTAL_SUPPLY);
    calldata.append_serde(payment_token.contract_address);
    calldata.append_serde(purchase_token.contract_address);
    calldata.append_serde(EMISSION_DURATION);
    calldata.append_serde(core_address);
    calldata.append_serde(positions_address);
    calldata.append_serde(extension_address);
    calldata.append_serde(PROCEEDS_DISTRIBUTION_DURATION);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_init_distribution_pool() {
    let contract_address = deploy_contract();
    let dispatcher = IEkuboDistributedERC20Dispatcher { contract_address };

    let pool_id_before = dispatcher.get_pool_id();
    assert(pool_id_before == 0, 'pool id should be 0');

    dispatcher.init_distribution_pool();

    let pool_id_after = dispatcher.get_pool_id();
    assert(pool_id_after != 0, 'pool id should be set');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_init_distribution_pool_twice() {
    let contract_address = deploy_contract();

    let safe_dispatcher = IEkuboDistributedERC20SafeDispatcher { contract_address };

    let pool_id_before = safe_dispatcher.get_pool_id().unwrap();
    assert(pool_id_before == 0, 'pool id should be 0');

    match safe_dispatcher.init_distribution_pool() {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'pool already initialized', *panic_data.at(0));
        }
    };
}
