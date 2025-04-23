# Vortex Smart Account

> Modular smart account framework implementing [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) and [ERC-7579](https://eips.ethereum.org/EIPS/eip-7579)

Vortex is a modular smart account implementation built on ERC-7579 and ERC-4337, designed for extensibility, modularity, and minimalism. It provides a flexible framework for validating user operations and executing arbitrary logic using plug-and-play modules.

## Overview

This repository contains the smart contracts for the Vortex Smart Account system, compliant with both ERC-7579 (modular account abstraction) and ERC-4337 (account abstraction via alt mempool).  
It enables customizable validation, execution, and fallback behavior via modules, allowing developers to compose smart accounts tailored to their use cases.

## Architecture

The architecture of Vortex Account Abstraction is designed to be modular, flexible, and secure, with each smart account being composed of independent modules for validation, execution, and runtime logic. Below is a high-level overview of the core components and their interactions.

### Core Components

- [Vortex](https://github.com/fomoweth/account-abstraction/blob/main/src/Vortex.sol): Handles the account’s core functionality, including interacting with modules, validating user operations, and executing transactions.
- [AccountCore](https://github.com/fomoweth/account-abstraction/blob/main/src/core/AccountCore.sol): Base contract implementing the ERC-7579 module interface and ERC-4337 compatibility.
- [ModuleManager](https://github.com/fomoweth/account-abstraction/blob/main/src/core/ModuleManager.sol): Manages the registration and resolution of modules per type.

### Factory

Enables the creation of modular smart accounts via a factory pattern, adhering to ERC-4337 and ERC-7579 specifications. Below is a list of available factories included in this repository.

- [MetaFactory](https://github.com/fomoweth/account-abstraction/blob/main/src/factories/MetaFactory.sol)
- [AccountFactory](https://github.com/fomoweth/account-abstraction/blob/main/src/factories/AccountFactory.sol)
- [K1ValidatorFactory](https://github.com/fomoweth/account-abstraction/blob/main/src/factories/K1ValidatorFactory.sol)
- [RegistryFactory](https://github.com/fomoweth/account-abstraction/blob/main/src/factories/RegistryFactory.sol)
- [ModuleFactory](https://github.com/fomoweth/account-abstraction/blob/main/src/factories/ModuleFactory.sol)

### Modules

The Vortex smart account is designed around ERC-7579 modules that plug into the account’s core functionality. Each module serves a specific purpose—validation, execution, or fallback handling—and can be enabled or disabled independently. Below is a list of available modules included in this repository.

### Validators

Modules responsible for verifying user operations before execution.

- [ECDSAValidator](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/validators/ECDSAValidator.sol)

- [K1Validator](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/validators/K1Validator.sol)

### Executors

Modules responsible for executing transactions on behalf of the smart account via a callback.

- [Permit2Executor](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/executors/Permit2Executor.sol)

- [UniversalExecutor](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/executors/UniversalExecutor.sol)

### Fallback Handlers

Modules responsible for extending the fallback functionality of a smart account.

- [NativeWrapperFallback](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/fallbacks/NativeWrapperFallback.sol)

- [STETHWrapperFallback](https://github.com/fomoweth/account-abstraction/blob/main/src/modules/fallbacks/STETHWrapperFallback.sol)

## Deployment

You can checkout the deployment information from [here](https://github.com/fomoweth/account-abstraction/blob/main/deployments/index.md)

## Usage

Create `.env` file with the following variables:

```text
# EOA
MNEMONIC="YOUR_MNEMONIC"
PRIVATE_KEY="YOUR_PRIVATE_KEY"
EOA_INDEX=0 # Optional (Default to 0)

# RPC URL Using Alchemy
RPC_API_KEY="YOUR_ALCHEMY_API_KEY"
ETHEREUM_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
OPTIMISM_RPC_URL="https://opt-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
POLYGON_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
ARBITRUM_RPC_URL="https://arb-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"

# RPC URL Using Infura
RPC_API_KEY="YOUR_INFURA_API_KEY"
ETHEREUM_RPC_URL="https://mainnet.infura.io/v3/${RPC_API_KEY}"
OPTIMISM_RPC_URL="https://optimism-mainnet.infura.io/v3/${RPC_API_KEY}"
POLYGON_RPC_URL="https://polygon-mainnet.infura.io/v3/${RPC_API_KEY}"
BASE_RPC_URL="https://base-mainnet.infura.io/v3/${RPC_API_KEY}"
ARBITRUM_RPC_URL="https://arbitrum-mainnet.infura.io/v3/${RPC_API_KEY}"

# Etherscan
ETHERSCAN_API_KEY_ETHEREUM="YOUR_ETHERSCAN_API_KEY"
ETHERSCAN_URL_ETHEREUM="https://api.etherscan.io/api"
ETHERSCAN_URL_SEPOLIA="https://api-sepolia.etherscan.io/api"

ETHERSCAN_API_KEY_OPTIMISM="YOUR_OPTIMISTIC_ETHERSCAN_API_KEY"
ETHERSCAN_URL_OPTIMISM="https://api-optimistic.etherscan.io/api"
ETHERSCAN_URL_OPTIMISM_SEPOLIA="https://api-sepolia-optimistic.etherscan.io/api"

ETHERSCAN_API_KEY_POLYGON="YOUR_POLYGONSCAN_API_KEY"
ETHERSCAN_URL_POLYGON="https://api.polygonscan.com/api"
ETHERSCAN_URL_POLYGON_AMOY="https://api-amoy.polygonscan.com/api"

ETHERSCAN_API_KEY_BASE="YOUR_BASESCAN_API_KEY"
ETHERSCAN_URL_BASE="https://api.basescan.org/api"
ETHERSCAN_URL_BASE_SEPOLIA="https://api-sepolia.basescan.org/api"

ETHERSCAN_API_KEY_ARBITRUM="YOUR_ARBISCAN_API_KEY"
ETHERSCAN_URL_ARBITRUM="https://api.arbiscan.io/api"
ETHERSCAN_URL_ARBITRUM_SEPOLIA="https://api-sepolia.arbiscan.io/api"
```

### Build

```shell
forge build --sizes
```

### Test

```shell
forge test --chain <CHAIN-ID>
```

### Deploy

```shell
forge script script/Deploy.s.sol --sig 'run()' --broadcast --verify --rpc-url <CHAIN-ID>
```

## Reference

The following repositories served as key references during the development of this project:

- [ERC-7579 / ERC-7579 Implementation](https://github.com/erc7579/erc7579-implementation) – Reference implementation of ERC-7579 standard, showcasing modular account architecture.
- [ZeroDev / Kernel](https://github.com/zerodevapp/kernel) – Modular smart account system demonstrating validator, executor, and hook architecture with ERC-7579 support.
- [Biconomy / Nexus](https://github.com/bcnmy/nexus) – ERC-4337 compliant smart account implementation with modular design, used as reference for factory and validator setup.
- [rhinestone / ModuleKit](https://github.com/rhinestonewtf/modulekit) – Lightweight framework for building and testing ERC-7579 modules, useful for structuring this project's module system.
- [Vectorized / Solady](https://github.com/Vectorized/solady) - Gas optimized Solidity snippets.

## Author

- [@fomoweth](https://github.com/fomoweth)
