# Check if required environment variables are set
required_vars=("STARKNET_NETWORK" "STARKNET_ACCOUNT" "STARKNET_KEYSTORE")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Error: The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo "Please set these variables before running the script."
    exit 1
fi

# erc2 config
name="0 0x68656c6c6f 5"
symbol="0 0x68656c6c6f 5"
token_supply=10000000000000000000000000000

# pool config
pool_fee=3402823669209384634633746074317682114
tick_spacing=354892
end_time=5905580032

# lords
payment_token="0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49"

# savâge
reward_address="0x004878d1148318a31829523ee9c6a5ee563af6cd87f90a30809e5b0d27db8a9b"

scarb build
class_hash=$(starkli declare --watch /workspaces/twamm-distributed-erc20/target/dev/gerc20_EkuboDistributedERC20.contract_class.json --compiler-version 2.7.1 2>/dev/null)

starkli deploy $class_hash $name $symbol $token_supply $pool_fee $end_time $tick_spacing $payment_token $reward_address $core_address $positions_address $extensions_address $registry_address
