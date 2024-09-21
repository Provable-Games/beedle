# Test Plan for EkuboDistributedERC20 Contract

## 1. Contract Reconnaissance

### 1.1 External/Public ABI Functions

| Function | Signature | Type |
|----------|-----------|------|
| constructor | `constructor(name: ByteArray, symbol: ByteArray, total_supply: u128, pool_fee: u128, tick_spacing: u32, payment_token: ContractAddress, reward_token: ContractAddress, core_address: ContractAddress, positions_address: ContractAddress, extension_address: ContractAddress, registry_address: ContractAddress)` | Mutating |
| init_distribution_pool | `init_distribution_pool()` | Mutating |
| start_token_distribution | `start_token_distribution(end_time: u64)` | Mutating |
| claim_and_sell_proceeds | `claim_and_sell_proceeds()` | Mutating |
| get_token_distribution_rate | `get_token_distribution_rate() -> u128` | View |
| get_reward_distribution_rate | `get_reward_distribution_rate() -> u128` | View |
| get_deployed_at | `get_deployed_at() -> u64` | View |
| get_distribution_end_time | `get_distribution_end_time() -> u64` | View |
| get_distribution_order_key | `get_distribution_order_key() -> OrderKey` | View |
| get_distribution_pool_key | `get_distribution_pool_key() -> PoolKey` | View |
| get_distribution_start_time | `get_distribution_start_time() -> u64` | View |
| get_pool_fee | `get_pool_fee() -> u128` | View |
| get_pool_id | `get_pool_id() -> u256` | View |
| get_position_token_id | `get_position_token_id() -> u64` | View |
| get_reward_distribution_duration | `get_reward_distribution_duration() -> u64` | View |
| get_reward_order_key | `get_reward_order_key() -> OrderKey` | View |
| get_payment_token | `get_payment_token() -> ContractAddress` | View |
| get_extension_address | `get_extension_address() -> ContractAddress` | View |
| get_reward_token | `get_reward_token() -> ContractAddress` | View |
| get_tick_spacing | `get_tick_spacing() -> u32` | View |

### 1.2 Internal/Helper Functions

| Function | Signature | Type |
|----------|-----------|------|
| _register_token | `_register_token(ref self: ContractState)` | Mutating |
| _get_distribution_pool_key | `_get_distribution_pool_key(self: @ContractState) -> PoolKey` | View |
| _get_distribution_order_key | `_get_distribution_order_key(self: @ContractState, start_time: u64, end_time: u64) -> OrderKey` | View |
| _get_reward_order_key | `_get_reward_order_key(self: @ContractState) -> OrderKey` | View |
| _to_nearest_valid_time | `_to_nearest_valid_time(block_time: u64, time: u64) -> u64` | Pure |
| _time_difference_to_step_size | `_time_difference_to_step_size(diff: u64) -> u64` | Pure |

### 1.3 State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| core_dispatcher | ICoreDispatcher | Ekubo core contract interface |
| deployed_at | u64 | Contract deployment timestamp |
| distribution_end_time | u64 | When token distribution ends |
| distribution_start_time | u64 | When token distribution starts |
| erc20 | ERC20Component::Storage | ERC20 token storage |
| extension_address | ContractAddress | Ekubo extension contract address |
| payment_token | ContractAddress | Token used for payments |
| pool_fee | u128 | Pool fee for distributions |
| pool_id | u256 | Initialized pool ID |
| positions_dispatcher | IPositionsDispatcher | Ekubo positions contract interface |
| position_token_id | u64 | TWAMM position token ID |
| registry_dispatcher | ITokenRegistryDispatcher | Token registry interface |
| reward_token | ContractAddress | Token to purchase with proceeds |
| reward_distribution_rate | u128 | Rate of reward token distribution |
| tick_spacing | u32 | Pool tick spacing |
| token_distribution_rate | u128 | Rate of token distribution |

### 1.4 Events

| Event | Source | Fields |
|-------|--------|--------|
| ERC20Event | ERC20Component | Standard ERC20 events (Transfer, Approval) |

### 1.5 Constants and Error Codes

| Constant | Value | Usage |
|----------|-------|-------|
| Errors::DISTRIBUTION_POOL_ALREADY_INITIALIZED | - | Pool already initialized |
| Errors::DISTRIBUTION_POOL_NOT_INITIALIZED | - | Pool not initialized |
| Errors::TOKEN_DISTRIBUTION_ALREADY_STARTED | - | Distribution already started |
| Errors::TOKEN_DISTRIBUTION_NOT_STARTED | - | Distribution not started |
| Errors::DISTRIBUTION_END_TIME_NOT_SET | - | End time not set |

## 2. Behaviour & Invariant Mapping

### 2.1 Constructor Function

**Purpose**: Initialize contract with ERC20 properties and Ekubo integration parameters

**Inputs & Edge Cases**:
- `name`: Empty ByteArray, very long ByteArray, special characters
- `symbol`: Empty ByteArray, very long ByteArray, special characters  
- `total_supply`: 0, 1, MAX_U128
- `pool_fee`: 0, standard fees, MAX_U128
- `tick_spacing`: 0, 1, standard values, MAX_U32
- `payment_token`: Zero address, valid address, contract address
- `reward_token`: Zero address, valid address, same as payment_token
- `core_address`: Zero address, valid address
- `positions_address`: Zero address, valid address
- `extension_address`: Zero address, valid address
- `registry_address`: Zero address, valid address

**Outputs & State Changes**:
- Initializes ERC20 component with name/symbol
- Sets all dispatcher addresses
- Sets configuration parameters
- Mints total_supply to contract address
- Registers token with registry
- Sets deployed_at timestamp

**Event Emissions**: Transfer event from minting, potential registry events

**Failure Conditions**:
- Any address parameter is zero address
- total_supply is 0
- Registry registration fails

**Invariants**:
- Contract always has total_supply tokens initially
- deployed_at equals block timestamp at construction
- All addresses are non-zero after construction

### 2.2 init_distribution_pool Function

**Purpose**: Initialize Ekubo pool for token distribution

**Inputs & Edge Cases**: None (no parameters)

**Outputs & State Changes**:
- Creates pool via core dispatcher
- Sets pool_id in storage

**Event Emissions**: Pool creation events from Ekubo core

**Failure Conditions**:
- Pool already initialized (pool_id != 0)
- Core dispatcher call fails

**Invariants**:
- pool_id becomes non-zero after successful call
- Function can only be called once successfully

### 2.3 start_token_distribution Function

**Purpose**: Start TWAP order to distribute entire token supply

**Inputs & Edge Cases**:
- `end_time`: Past timestamp, current timestamp, far future, block_time aligned/unaligned

**Outputs & State Changes**:
- Transfers total supply to positions contract
- Creates TWAMM sell order
- Sets distribution times and position token ID
- Sets token distribution rate

**Event Emissions**: Transfer events, TWAMM position events

**Failure Conditions**:
- Pool not initialized
- Distribution already started
- end_time validation failures
- Positions contract call failures

**Invariants**:
- position_token_id becomes non-zero after call
- distribution_start_time is block-aligned
- Contract token balance becomes 0 after transfer

### 2.4 claim_and_sell_proceeds Function

**Purpose**: Claim proceeds from token sales and reinvest in reward tokens

**Inputs & Edge Cases**: None (no parameters)

**Outputs & State Changes**:
- Withdraws proceeds from position
- Creates new sell order for reward tokens
- Updates reward distribution rate

**Event Emissions**: Position withdrawal events, new order events

**Failure Conditions**:
- Pool not initialized
- Distribution not started
- No proceeds available
- Positions contract call failures

**Invariants**:
- reward_distribution_rate increases or stays same
- Proceeds are fully reinvested

### 2.5 Getter Functions

All getter functions should return consistent state values without mutations.

**Failure Conditions**:
- get_reward_distribution_duration: distribution_end_time not set

**Invariants**:
- All getters return consistent values
- Internal getters match public getters

## 3. Unit Test Design

### 3.1 Constructor Tests

**Happy Path Tests**:
- `UT_CONSTRUCTOR_001`: Valid parameters with standard values
- `UT_CONSTRUCTOR_002`: Minimum valid total_supply (1)
- `UT_CONSTRUCTOR_003`: Maximum valid total_supply (MAX_U128)

**Revert Path Tests**:
- `UT_CONSTRUCTOR_REVERT_001`: Zero payment_token address
- `UT_CONSTRUCTOR_REVERT_002`: Zero reward_token address  
- `UT_CONSTRUCTOR_REVERT_003`: Zero core_address
- `UT_CONSTRUCTOR_REVERT_004`: Zero positions_address
- `UT_CONSTRUCTOR_REVERT_005`: Zero extension_address
- `UT_CONSTRUCTOR_REVERT_006`: Zero registry_address
- `UT_CONSTRUCTOR_REVERT_007`: Zero total_supply

**Boundary Tests**:
- `UT_CONSTRUCTOR_BOUNDARY_001`: Empty name and symbol
- `UT_CONSTRUCTOR_BOUNDARY_002`: Very long name and symbol
- `UT_CONSTRUCTOR_BOUNDARY_003`: Zero pool_fee and tick_spacing

### 3.2 init_distribution_pool Tests

**Happy Path Tests**:
- `UT_INIT_POOL_001`: First successful initialization

**Revert Path Tests**:
- `UT_INIT_POOL_REVERT_001`: Pool already initialized
- `UT_INIT_POOL_REVERT_002`: Core dispatcher failure

### 3.3 start_token_distribution Tests

**Happy Path Tests**:
- `UT_START_DIST_001`: Valid future end_time
- `UT_START_DIST_002`: End_time exactly aligned to block boundaries

**Revert Path Tests**:
- `UT_START_DIST_REVERT_001`: Pool not initialized
- `UT_START_DIST_REVERT_002`: Distribution already started
- `UT_START_DIST_REVERT_003`: Past end_time
- `UT_START_DIST_REVERT_004`: Positions contract failure

**Boundary Tests**:
- `UT_START_DIST_BOUNDARY_001`: end_time equals current block_time
- `UT_START_DIST_BOUNDARY_002`: Maximum future end_time

### 3.4 claim_and_sell_proceeds Tests

**Happy Path Tests**:
- `UT_CLAIM_001`: First claim with available proceeds
- `UT_CLAIM_002`: Multiple claims over time

**Revert Path Tests**:
- `UT_CLAIM_REVERT_001`: Pool not initialized
- `UT_CLAIM_REVERT_002`: Distribution not started
- `UT_CLAIM_REVERT_003`: No proceeds available
- `UT_CLAIM_REVERT_004`: Positions contract failure

### 3.5 Getter Function Tests

**Happy Path Tests**:
- `UT_GETTERS_001`: All getters return expected values after construction
- `UT_GETTERS_002`: All getters return expected values after distribution start
- `UT_GETTERS_003`: Time-dependent getters return consistent values

**Revert Path Tests**:
- `UT_GETTERS_REVERT_001`: get_reward_distribution_duration when end_time not set

### 3.6 Internal Function Tests

**Helper Function Tests**:
- `UT_HELPERS_001`: _to_nearest_valid_time with various inputs
- `UT_HELPERS_002`: _time_difference_to_step_size boundary cases
- `UT_HELPERS_003`: Pool and order key generation consistency

## 4. Fuzz & Property-Based Tests

### 4.1 Constructor Fuzz Tests

**Properties**:
- Contract always has total_supply tokens after construction
- All non-zero addresses remain non-zero
- deployed_at matches block timestamp

**Fuzzing Strategy**:
- `FUZZ_CONSTRUCTOR_001`: Random valid addresses and parameters
- Input domains: total_supply (1 to MAX_U128), valid contract addresses
- Mutation: Address bit flipping, supply scaling

### 4.2 Distribution Flow Fuzz Tests

**Properties**:
- Pool can only be initialized once
- Distribution can only be started once
- Token balance conservation throughout process

**Fuzzing Strategy**:
- `FUZZ_DISTRIBUTION_001`: Random end_times within valid ranges
- `FUZZ_DISTRIBUTION_002`: Multiple claim attempts with time progression
- Input domains: end_time (current + 1 to current + MAX_U64/2)

### 4.3 Time Calculation Fuzz Tests

**Properties**:
- _to_nearest_valid_time always returns time >= input time
- Returned time is always properly aligned
- Function terminates within reasonable bounds

**Fuzzing Strategy**:
- `FUZZ_TIME_001`: Random block_time and target_time combinations
- Input domains: time differences (0 to MAX_U64/4)
- Negative cases: Past times, overflow scenarios

### 4.4 Invariant Testing

**Continuous Invariants**:
- `INV_001`: Total token supply conservation
- `INV_002`: State transition monotonicity (pool_id, position_token_id)
- `INV_003`: Time ordering (start_time <= end_time)
- `INV_004`: Rate accumulation (reward_distribution_rate increases)

## 5. Integration & Scenario Tests

### 5.1 Complete Distribution Flow

**Scenario Tests**:
- `INT_FLOW_001`: Complete happy path: constructor → init_pool → start_distribution → multiple claims
- `INT_FLOW_002`: Multi-user interaction with ERC20 functions during distribution
- `INT_FLOW_003`: Distribution with zero proceeds (no buyers)

### 5.2 Time-Based Scenarios  

**Scenario Tests**:
- `INT_TIME_001`: Distribution spanning multiple time boundaries
- `INT_TIME_002`: Claims at various distribution progress points
- `INT_TIME_003`: End-time boundary conditions

### 5.3 Adversarial Scenarios

**Scenario Tests**:
- `INT_ADV_001`: Attempt operations in wrong order
- `INT_ADV_002`: Reentrancy attempts during external calls
- `INT_ADV_003`: Front-running distribution initialization

### 5.4 Edge Case Integration

**Scenario Tests**:
- `INT_EDGE_001`: Minimal total_supply (1 token) distribution
- `INT_EDGE_002`: Maximum time duration distributions
- `INT_EDGE_003`: Rapid successive claims

## 6. Coverage Matrix

| Function/Invariant | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Event |
|-------------------|------------|-------------|------|----------|-------------|-------|
| constructor | UT_CONSTRUCTOR_001-003 | UT_CONSTRUCTOR_REVERT_001-007 | FUZZ_CONSTRUCTOR_001 | INV_001-003 | INT_FLOW_001 | Transfer |
| init_distribution_pool | UT_INIT_POOL_001 | UT_INIT_POOL_REVERT_001-002 | - | INV_002 | INT_FLOW_001 | Pool events |
| start_token_distribution | UT_START_DIST_001-002 | UT_START_DIST_REVERT_001-004 | FUZZ_DISTRIBUTION_001 | INV_001-003 | INT_FLOW_001-003 | Transfer, Position |
| claim_and_sell_proceeds | UT_CLAIM_001-002 | UT_CLAIM_REVERT_001-004 | FUZZ_DISTRIBUTION_002 | INV_004 | INT_FLOW_001-003 | Position events |
| All getters | UT_GETTERS_001-003 | UT_GETTERS_REVERT_001 | - | - | INT_FLOW_001 | - |
| _to_nearest_valid_time | UT_HELPERS_001 | - | FUZZ_TIME_001 | Time alignment | INT_TIME_001-003 | - |
| _time_difference_to_step_size | UT_HELPERS_002 | - | FUZZ_TIME_001 | Step size correctness | INT_TIME_001-003 | - |
| State transitions | - | - | - | INV_001-004 | INT_FLOW_001-003 | - |
| Reentrancy protection | - | - | - | - | INT_ADV_002 | - |

## 7. Tooling & Environment

### 7.1 Framework Requirements

**Primary Framework**: Scarb with Cairo test framework
**Additional Tools**: 
- Starknet Foundry for advanced testing
- Custom mock contracts for Ekubo interfaces

### 7.2 Required Mocks

**Mock Contracts**:
- `MockICoreDispatcher`: Simulates Ekubo core functionality
- `MockIPositionsDispatcher`: Simulates TWAMM position management  
- `MockITokenRegistryDispatcher`: Simulates token registry
- `MockERC20`: For payment_token and reward_token testing

**Mock Behaviors**:
- Configurable success/failure responses
- Event emission simulation
- State tracking for assertions

### 7.3 Directory Structure

```
tests/
├── unit/
│   ├── test_constructor.cairo
│   ├── test_distribution_pool.cairo
│   ├── test_token_distribution.cairo
│   ├── test_claim_proceeds.cairo
│   ├── test_getters.cairo
│   └── test_helpers.cairo
├── integration/
│   ├── test_complete_flows.cairo
│   ├── test_time_scenarios.cairo
│   └── test_adversarial.cairo
├── fuzz/
│   ├── test_constructor_fuzz.cairo
│   ├── test_distribution_fuzz.cairo
│   └── test_time_fuzz.cairo
├── mocks/
│   ├── mock_core.cairo
│   ├── mock_positions.cairo
│   ├── mock_registry.cairo
│   └── mock_erc20.cairo
└── lib.cairo
```

### 7.4 Coverage Measurement

**Commands**:
```bash
scarb test --coverage
starknet-foundry test --coverage-report lcov
```

**Thresholds**:
- Line coverage: 100%
- Branch coverage: 100%  
- Function coverage: 100%

### 7.5 Naming Conventions

**Test Functions**: `test_{category}_{description}_{case_number}`
**Mock Functions**: `mock_{interface}_{behavior}`
**Constants**: `CONST_{PURPOSE}_{IDENTIFIER}`
**Helper Functions**: `helper_{purpose}_{description}`

## 8. Self-Audit

### 8.1 Branch Coverage Verification

**All Assert/Require Statements Covered**:
- ✓ Constructor parameter validations (7 assertions)
- ✓ Pool initialization state check (1 assertion)  
- ✓ Distribution start state checks (2 assertions)
- ✓ Claim proceeds state checks (2 assertions)
- ✓ Reward distribution duration check (1 assertion)

**All Conditional Branches Covered**:
- ✓ Pool key token ordering logic
- ✓ Time calculation loop termination
- ✓ Step size calculation branches

### 8.2 Event Coverage Verification

**All Events Mapped**:
- ✓ ERC20 Transfer events (constructor minting, distribution transfer)
- ✓ ERC20 Approval events (if any approval calls)
- ✓ External contract events (Ekubo pool, position, registry events)

### 8.3 State Mutation Coverage

**All State-Changing Operations Covered**:
- ✓ Storage writes in constructor (12 state variables)
- ✓ Storage writes in init_distribution_pool (1 state variable)
- ✓ Storage writes in start_token_distribution (4 state variables) 
- ✓ Storage writes in claim_and_sell_proceeds (1 state variable)
- ✓ ERC20 component state changes (minting, transfers)

### 8.4 Function Coverage Verification

**All Functions Tested**:
- ✓ All 20 public interface functions
- ✓ All 6 internal helper functions
- ✓ All getter function variants
- ✓ ERC20 inherited functions (via component testing)

### 8.5 Discrepancy Analysis

**Identified Issues**: None

**Uncovered Code Paths**: None - all branches, events, and state mutations are mapped to specific test cases in the coverage matrix.

**Risk Assessment**: Test plan provides comprehensive coverage for all contract functionality, state transitions, error conditions, and integration scenarios. 