use core::result::ResultTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::contract_address_const;

#[test]
fn test_simple_deployment() {
    let contract = declare("EkuboDistributedERC20").unwrap().contract_class();

    // Mock the registry
    let registry_address = contract_address_const::<0x4444444444>();
    mock_call(registry_address, selector!("register_token"), (), 100);

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

    println!("Deploying contract...");
    let deploy_result = contract.deploy(@constructor_calldata);

    match deploy_result {
        Result::Ok((
            address, _,
        )) => {
            println!("Deployment successful at: {:?}", address);
            assert(true, 'Deploy succeeded');
        },
        Result::Err(_e) => {
            println!("Deployment failed with error");
            assert(false, 'Deploy failed');
        },
    }
}
