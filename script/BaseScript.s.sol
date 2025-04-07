// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2 as console, stdJson} from "forge-std/Script.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IRegistry} from "src/interfaces/registries/IRegistry.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {ModuleFactory} from "src/factories/ModuleFactory.sol";
import {Deploy} from "test/shared/utils/Deploy.sol";

abstract contract BaseScript is Script {
	using stdJson for string;

	error UnsupportedChain(uint256 chainId);
	error ContractNotExists(string name);

	string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

	uint256 internal constant ETHEREUM_CHAIN_ID = 1;
	uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

	uint256 internal constant OPTIMISM_CHAIN_ID = 10;
	uint256 internal constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

	uint256 internal constant POLYGON_CHAIN_ID = 137;
	uint256 internal constant POLYGON_AMOY_CHAIN_ID = 80002;

	uint256 internal constant BASE_CHAIN_ID = 8453;
	uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

	uint256 internal constant ARBITRUM_CHAIN_ID = 42161;
	uint256 internal constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	/// @dev Rhinestone Registry
	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	bytes32 internal constant RESOLVER_UID = 0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f;

	address internal broadcaster = vm.rememberKey(configurePrivateKey());

	string internal config;

	modifier broadcast() {
		vm.startBroadcast(broadcaster);
		_;
		vm.stopBroadcast();
	}

	function setUp() public virtual {
		string memory path = getDeploymentsPath(chainAlias());

		if (!vm.isFile(path)) {
			string memory root = "root";
			root.serialize("chainId", block.chainid);

			string memory template = vm.readFile(getDeploymentsPath("template"));
			vm.writeFile(path, root.serialize("deployments", template));
		}

		config = vm.readFile(path);
	}

	function configurePrivateKey() internal virtual returns (uint256 privateKey) {
		privateKey = vm.envOr({
			name: "PRIVATE_KEY",
			defaultValue: vm.deriveKey({
				mnemonic: vm.envOr({name: "MNEMONIC", defaultValue: TEST_MNEMONIC}),
				index: uint8(vm.envOr({name: "EOA_INDEX", defaultValue: uint256(0)}))
			})
		});
	}

	function constructJson(
		address instance,
		address deployer,
		bytes32 salt,
		uint256 timestamp
	) internal virtual returns (string memory output) {
		if (instance == address(0)) (deployer, salt, timestamp) = (address(0), bytes32(0), uint256(0));

		output = "deployment";
		output.serialize("address", instance);
		output.serialize("deployer", deployer);
		output.serialize("salt", salt);
		return output.serialize("timestamp", timestamp);
	}

	function constructJson(
		address instance,
		address deployer,
		bytes32 salt,
		bytes32 txHash,
		uint256 timestamp
	) internal virtual returns (string memory output) {
		output = "deployment";
		output.serialize("address", instance);
		output.serialize("deployer", deployer);
		output.serialize("salt", salt);
		output.serialize("txHash", txHash);
		return output.serialize("timestamp", timestamp);
	}

	function getAddress(string memory name) internal view virtual returns (address a) {
		string memory key = string.concat(".deployments.", name, ".address");
		require((a = config.readAddress(key)) != address(0), ContractNotExists(name));
	}

	function getContractSalt(string memory name) internal view virtual returns (bytes32 salt) {
		string memory key = string.concat(".deployments.", name);
		require(config.keyExists(key), ContractNotExists(name));
		return config.readBytes32(string.concat(key, ".salt"));
	}

	function getDeploymentsPath(string memory key) internal view virtual returns (string memory) {
		return string.concat("deployments/", key, ".json");
	}

	function getModuleFactory() internal view virtual returns (ModuleFactory) {
		return ModuleFactory(getAddress("ModuleFactory"));
	}

	function chainAlias() internal view virtual returns (string memory) {
		uint256 chainId = block.chainid;
		if (chainId == ETHEREUM_CHAIN_ID) {
			return "ethereum";
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			return "sepolia";
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			return "optimism";
		} else if (chainId == OPTIMISM_SEPOLIA_CHAIN_ID) {
			return "optimism-sepolia";
		} else if (chainId == POLYGON_CHAIN_ID) {
			return "polygon";
		} else if (chainId == POLYGON_AMOY_CHAIN_ID) {
			return "polygon-amoy";
		} else if (chainId == BASE_CHAIN_ID) {
			return "base";
		} else if (chainId == BASE_SEPOLIA_CHAIN_ID) {
			return "base-sepolia";
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			return "arbitrum";
		} else if (chainId == ARBITRUM_SEPOLIA_CHAIN_ID) {
			return "arbitrum-sepolia";
		} else {
			revert UnsupportedChain(chainId);
		}
	}

	function wrappedNative() internal view virtual returns (address) {
		uint256 chainId = block.chainid;
		if (chainId == ETHEREUM_CHAIN_ID) {
			return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			return 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			return 0x4200000000000000000000000000000000000006;
		} else if (chainId == OPTIMISM_SEPOLIA_CHAIN_ID) {
			return 0x4200000000000000000000000000000000000006;
		} else if (chainId == POLYGON_CHAIN_ID) {
			return 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
		} else if (chainId == POLYGON_AMOY_CHAIN_ID) {
			return 0xA5733b3A8e62A8faF43b0376d5fAF46E89B3033E;
		} else if (chainId == BASE_CHAIN_ID) {
			return 0x4200000000000000000000000000000000000006;
		} else if (chainId == BASE_SEPOLIA_CHAIN_ID) {
			return 0x4200000000000000000000000000000000000006;
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
		} else if (chainId == ARBITRUM_SEPOLIA_CHAIN_ID) {
			return 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
		} else {
			revert UnsupportedChain(chainId);
		}
	}

	function isContract(address target) internal view returns (bool result) {
		assembly ("memory-safe") {
			result := iszero(iszero(extcodesize(target)))
		}
	}
}
