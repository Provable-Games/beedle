use starknet::{ContractAddress, contract_address_const};

pub mod Errors {
    pub const TOKEN_DISTRIBUTION_ALREADY_STARTED: felt252 = 'distribution already started';
    pub const TOKEN_DISTRIBUTION_NOT_STARTED: felt252 = 'distribution not started';
    pub const DISTRIBUTION_POOL_NOT_INITIALIZED: felt252 = 'dist pool not initialized';
    pub const DISTRIBUTION_POOL_ALREADY_INITIALIZED: felt252 = 'pool already initialized';
    pub const DISTRIBUTION_END_TIME_NOT_SET: felt252 = 'end time not set';
    pub const TOKEN_ALREADY_REGISTERED: felt252 = 'token already registered';
    pub const DISTRIBUTION_DELAY_STILL_ACTIVE: felt252 = 'distribution delay still active';
}

const MAINNET_CHAIN_ID: felt252 = 0x534e5f4d41494e;
const SEPOLIA_CHAIN_ID: felt252 = 0x534e5f5345504f4c4941;
pub const MAX_TICK_SPACING: u32 = 354892;

pub fn get_core_address(chain_id: felt252) -> ContractAddress {
    if chain_id == MAINNET_CHAIN_ID {
        contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b
        >()
    } else if chain_id == SEPOLIA_CHAIN_ID {
        contract_address_const::<
            0x0444a09d96389aa7148f1aada508e30b71299ffe650d9c97fdaae38cb9a23384
        >()
    } else {
        panic!("unsupported chain")
    }
}

pub fn get_twamm_extension_address(chain_id: felt252) -> ContractAddress {
    if chain_id == MAINNET_CHAIN_ID {
        contract_address_const::<
            0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc
        >()
    } else if chain_id == SEPOLIA_CHAIN_ID {
        contract_address_const::<
            0x073ec792c33b52d5f96940c2860d512b3884f2127d25e023eb9d44a678e4b971
        >()
    } else {
        panic!("unsupported chain")
    }
}

pub fn get_positions_address(chain_id: felt252) -> ContractAddress {
    if chain_id == MAINNET_CHAIN_ID {
        contract_address_const::<
            0x07b696af58c967c1b14c9dde0ace001720635a660a8e90c565ea459345318b30
        >()
    } else if chain_id == SEPOLIA_CHAIN_ID {
        contract_address_const::<
            0x04afc78d6fec3b122fc1f60276f074e557749df1a77a93416451be72c435120f
        >()
    } else {
        panic!("unsupported chain")
    }
}

pub fn get_registry_address(chain_id: felt252) -> ContractAddress {
    if chain_id == MAINNET_CHAIN_ID {
        contract_address_const::<
            0x064bdb4094881140bc39340146c5fcc5a187a98aec5a53f448ac702e5de5067e
        >()
    } else if chain_id == SEPOLIA_CHAIN_ID {
        contract_address_const::<
            0x04484f91f0d2482bad844471ca8dc8e846d3a0211792322e72f21f0f44be63e5
        >()
    } else {
        panic!("unsupported chain")
    }
}
