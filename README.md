# Account Abstraction

[ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579)

## Overview

## Usage

Create `.env` file with the following content:

```text
# using Alchemy

ALCHEMY_API_KEY=YOUR_ALCHEMY_API_KEY
RPC_ETHEREUM="https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}"
RPC_OPTIMISM="https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}"
RPC_POLYGON="https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}"
RPC_ARBITRUM="https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}"
RPC_BASE="https://base-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}"

# using Infura

INFURA_API_KEY=YOUR_INFURA_API_KEY
RPC_ETHEREUM="https://mainnet.infura.io/v3/${INFURA_API_KEY}"
RPC_OPTIMISM="https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}"
RPC_POLYGON="https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}"
RPC_ARBITRUM="https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}"
RPC_BASE="https://base-mainnet.infura.io/v3/${INFURA_API_KEY}"

# etherscan

ETHERSCAN_API_KEY_ETHEREUM=YOUR_ETHERSCAN_API_KEY_ETHEREUM
ETHERSCAN_URL_ETHEREUM="https://api.etherscan.io/api"

ETHERSCAN_API_KEY_OPTIMISM=YOUR_ETHERSCAN_API_KEY_OPTIMISM
ETHERSCAN_URL_OPTIMISM="https://api-optimistic.etherscan.io/api"

ETHERSCAN_API_KEY_POLYGON=YOUR_ETHERSCAN_API_KEY_POLYGON
ETHERSCAN_URL_POLYGON="https://api.polygonscan.com/api"

ETHERSCAN_API_KEY_ARBITRUM=YOUR_ETHERSCAN_API_KEY_ARBITRUM
ETHERSCAN_URL_ARBITRUM="https://api.arbiscan.io/api"

ETHERSCAN_API_KEY_BASE=YOUR_ETHERSCAN_API_KEY_BASE
ETHERSCAN_URL_BASE="https://api.basescan.org/api"
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
