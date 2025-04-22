// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2 as console} from "forge-std/Script.sol";
import {Permit2Executor} from "src/modules/executors/Permit2Executor.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";
import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {STETHWrapperFallback} from "src/modules/fallbacks/STETHWrapperFallback.sol";
import {ECDSAValidator} from "src/modules/validators/ECDSAValidator.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";
import {AccountFactory} from "src/factories/AccountFactory.sol";
import {K1ValidatorFactory} from "src/factories/K1ValidatorFactory.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {ModuleFactory} from "src/factories/ModuleFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {Bootstrap} from "src/utils/Bootstrap.sol";
import {Vortex} from "src/Vortex.sol";

contract Deploy is Script {
	error UnsupportedChain(uint256 chainId);

	string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

	bytes32 internal constant SALT = 0x0000000000000000000000000000000000000000000000000000000000007579;

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

	/// @dev Rhinestone Registry
	address internal constant REGISTRY = 0x000000000069E2a187AEFFb852bF3cCdC95151B2;

	uint256 internal privateKey = configurePrivateKey();
	address internal broadcaster = vm.rememberKey(privateKey);

	modifier broadcast() {
		vm.startBroadcast(broadcaster);
		_;
		vm.stopBroadcast();
	}

	function run() external broadcast {
		uint256 chainId = block.chainid;
		address deployer = broadcaster;

		console.log("======================================================================");
		console.log("\nDeploying Core Contracts\n");

		MetaFactory metaFactory = new MetaFactory{salt: SALT}(deployer);
		console.log("MetaFactory Deployed:", address(metaFactory));

		ModuleFactory moduleFactory = new ModuleFactory{salt: SALT}(REGISTRY);
		console.log("ModuleFactory Deployed:", address(moduleFactory));

		address vortex = address(new Vortex{salt: SALT}());
		console.log("Vortex V1 Implementation Deployed:", vortex);

		address bootstrap = address(new Bootstrap{salt: SALT}());
		console.log("Bootstrap Deployed:", bootstrap);

		address k1Validator = moduleFactory.deployModule(SALT, type(K1Validator).creationCode, "");
		console.log("K1Validator Deployed:", k1Validator);

		console.log("\nDeploying Account Factories\n");

		address accountFactory = address(new AccountFactory{salt: SALT}(vortex, deployer));
		console.log("AccountFactory Deployed:", accountFactory);

		RegistryFactory registryFactory = new RegistryFactory{salt: SALT}(vortex, bootstrap, REGISTRY, deployer);
		console.log("RegistryFactory Deployed:", address(registryFactory));

		address k1ValidatorFactory = address(
			new K1ValidatorFactory{salt: SALT}(vortex, k1Validator, bootstrap, REGISTRY, deployer)
		);
		console.log("K1ValidatorFactory Deployed:", k1ValidatorFactory);

		console.log("\nDeploying ERC-7579 Modules\n");

		console.log(
			"ECDSAValidator Deployed:",
			moduleFactory.deployModule(SALT, type(ECDSAValidator).creationCode, "")
		);

		console.log(
			"Permit2Executor Deployed:",
			moduleFactory.deployModule(SALT, type(Permit2Executor).creationCode, "")
		);

		console.log(
			"UniversalExecutor Deployed:",
			moduleFactory.deployModule(SALT, type(UniversalExecutor).creationCode, abi.encode(wrappedNative(chainId)))
		);

		console.log(
			"NativeWrapperFallback Deployed:",
			moduleFactory.deployModule(
				SALT,
				type(NativeWrapperFallback).creationCode,
				abi.encode(wrappedNative(chainId))
			)
		);

		if (chainId == ETHEREUM_CHAIN_ID || chainId == SEPOLIA_CHAIN_ID) {
			console.log(
				"STETHWrapperFallback Deployed:",
				moduleFactory.deployModule(
					SALT,
					type(STETHWrapperFallback).creationCode,
					abi.encode(stETH(chainId), wstETH(chainId))
				)
			);
		}

		metaFactory.authorize(accountFactory);
		metaFactory.authorize(k1ValidatorFactory);
		metaFactory.authorize(address(registryFactory));

		console.log("\nAuthorized Account Factories\n");

		address[] memory attesters = vm.envAddress("ATTESTERS", ",");

		if (attesters.length != 0) {
			uint8 threshold = uint8(vm.envOr({name: "THRESHOLD", defaultValue: uint256(1)}));
			registryFactory.configure(attesters, threshold);

			console.log("\nConfigured Attesters and Threshold for RegistryFactory");
		}

		console.log("\n======================================================================\n");
	}

	function configurePrivateKey() internal virtual returns (uint256) {
		return
			vm.envOr({
				name: "PRIVATE_KEY",
				defaultValue: vm.deriveKey({
					mnemonic: vm.envOr({name: "MNEMONIC", defaultValue: TEST_MNEMONIC}),
					index: uint8(vm.envOr({name: "EOA_INDEX", defaultValue: uint256(0)}))
				})
			});
	}

	function wrappedNative(uint256 chainId) internal view virtual returns (address) {
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

	function stETH(uint256 chainId) internal view virtual returns (address) {
		if (chainId == ETHEREUM_CHAIN_ID) {
			return 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			return 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
		} else {
			revert UnsupportedChain(chainId);
		}
	}

	function wstETH(uint256 chainId) internal view virtual returns (address) {
		if (chainId == ETHEREUM_CHAIN_ID) {
			return 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			return 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
		} else {
			revert UnsupportedChain(chainId);
		}
	}
}
