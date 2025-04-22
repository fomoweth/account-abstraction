# Account Abstraction

[ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579)

## Overview

## Usage

Create `.env` file with the following content:

```text
# EOA

MNEMONIC=YOUR_MNEMONIC
PRIVATE_KEY=YOUR_PRIVATE_KEY
EOA_INDEX=0 # Optional (Default to 0)

# Using Alchemy

RPC_API_KEY="YOUR_ALCHEMY_API_KEY"
ETHEREUM_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
OPTIMISM_RPC_URL="https://opt-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
POLYGON_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"
ARBITRUM_RPC_URL="https://arb-mainnet.g.alchemy.com/v2/${RPC_API_KEY}"

# Using Infura

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
$ forge build --sizes
```

### Test

```shell
$ forge test --chain <CHAIN-ID>
```

### Deploy

```shell
$ forge script script/DeployAll.s.sol -vv --broadcast --verify --rpc-url <CHAIN-ID || CHAIN-NAME>
```
