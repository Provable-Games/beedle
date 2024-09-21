# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cairo smart contract project that creates and distributes ERC20 tokens using Ekubo's TWAMM (Time-Weighted Average Market Maker) protocol on Starknet. The contract mints tokens and gradually sells them over time through a TWAMM order, then reinvests the proceeds into a reward token.

## Build and Development Commands

### Core Commands
- `scarb build` - Compile Cairo smart contracts
- `scarb test` - Run tests using snforge
- `scarb fmt` - Format code according to Cairo style guidelines
- `scarb check` - Analyze code for errors without building
- `scarb clean` - Remove generated artifacts

### Deployment
- `./scripts/deploy.sh` - Deploy the contract (requires STARKNET_NETWORK, STARKNET_ACCOUNT, STARKNET_KEYSTORE environment variables)

### Utilities
- `ts-node scripts/twammTimestamps.ts <blockTime> <time> [roundUp]` - Calculate TWAMM timestamps

## Architecture

### Contract Structure
- `src/contract.cairo` - Main EkuboDistributedERC20 implementation
- `src/interfaces.cairo` - Public interface definitions
- `src/constants.cairo` - Error message constants

### Key Components
1. **ERC20 Base**: Inherits from OpenZeppelin's ERC20Component
2. **Distribution Logic**: Manages TWAMM orders on Ekubo
3. **Token Registry**: Registers tokens with Ekubo's registry

### External Dependencies
- OpenZeppelin contracts for ERC20 functionality
- Ekubo protocol for TWAMM, pools, and positions
- Starknet Foundry (snforge) for testing

### Distribution Flow
1. Contract mints total supply to itself on deployment
2. `init_distribution_pool()` creates Ekubo liquidity pool
3. `start_token_distribution(end_time)` begins TWAMM sell order
4. `claim_and_sell_proceeds()` collects payments and buys reward tokens

### Key Addresses (stored in contract)
- `ekubo_core`: Core Ekubo contract
- `ekubo_positions`: Positions management contract
- `twamm_contract`: TWAMM extension contract
- `token_registry`: Token registry contract
- `payment_token`: Token received for sales (e.g., LORDS)
- `reward_token`: Token purchased with proceeds

## Testing
Tests should verify:
- Token minting and distribution mechanics
- TWAMM order creation and management
- Proceeds claiming and reinvestment
- Integration with Ekubo protocol

## Important Notes
- Each contract instance represents one token distribution
- Distribution parameters are immutable after deployment
- The contract operates autonomously once distribution starts
- All Ekubo interactions use dispatcher patterns for cross-contract calls