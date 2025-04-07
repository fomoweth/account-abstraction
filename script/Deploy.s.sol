// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {Deploy, MetaFactory, ModuleFactory} from "test/shared/utils/Deploy.sol";
import {BaseScript} from "./BaseScript.s.sol";

contract DeployScript is BaseScript {
	using stdJson for string;

	struct Deployment {
		address deployer;
		address instance;
		bytes32 hash;
		bytes32 salt;
		uint256 timestamp;
	}

	struct Deployments {
		MetaFactory metaFactory;
		address accountFactory;
		address k1ValidatorFactory;
		address registryFactory;
		ModuleFactory moduleFactory;
		address k1Validator;
		address permit2Executor;
		address universalExecutor;
		address nativeWrapper;
		address stETHWrapper;
		address bootstrap;
		address vortex;
		address deployer;
		bytes32 salt;
		uint256 timestamp;
	}

	function run() external {
		bytes32 salt = 0x0000000000000000000000000000000000000000000000000000000999999999;
		Deployments memory output = deploy(block.chainid, salt);
		constructJson(output);
	}

	function deploy(uint256 chainId, bytes32 salt) internal virtual broadcast returns (Deployments memory output) {
		address WETH;
		address stETH;
		address wstETH;

		if (chainId == ETHEREUM_CHAIN_ID) {
			WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
			stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
			wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
			stETH = 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
			wstETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			WETH = 0x4200000000000000000000000000000000000006;
		} else if (chainId == OPTIMISM_SEPOLIA_CHAIN_ID) {
			WETH = 0x4200000000000000000000000000000000000006;
		} else if (chainId == POLYGON_CHAIN_ID) {
			WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
		} else if (chainId == POLYGON_AMOY_CHAIN_ID) {
			WETH = 0xA5733b3A8e62A8faF43b0376d5fAF46E89B3033E;
		} else if (chainId == BASE_CHAIN_ID) {
			WETH = 0x4200000000000000000000000000000000000006;
		} else if (chainId == BASE_SEPOLIA_CHAIN_ID) {
			WETH = 0x4200000000000000000000000000000000000006;
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
		} else if (chainId == ARBITRUM_SEPOLIA_CHAIN_ID) {
			WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
		} else {
			revert UnsupportedChain(chainId);
		}

		output.deployer = broadcaster;
		output.salt = salt;
		output.timestamp = vm.getBlockTimestamp();

		output.metaFactory = Deploy.metaFactory(salt, output.deployer);
		output.moduleFactory = Deploy.moduleFactory(salt, address(REGISTRY), RESOLVER_UID);

		output.vortex = address(Deploy.vortex(salt));
		output.bootstrap = address(Deploy.bootstrap(salt));
		output.k1Validator = address(Deploy.k1Validator(output.moduleFactory, salt));

		output.accountFactory = address(Deploy.accountFactory(salt, output.vortex));
		output.k1ValidatorFactory = address(
			Deploy.k1ValidatorFactory(salt, output.vortex, output.bootstrap, output.k1Validator)
		);
		output.registryFactory = address(
			Deploy.registryFactory(salt, output.vortex, output.bootstrap, address(REGISTRY), output.deployer)
		);

		output.permit2Executor = address(Deploy.permit2Executor(output.moduleFactory, salt));
		output.universalExecutor = address(Deploy.universalExecutor(output.moduleFactory, salt, WETH));
		output.nativeWrapper = address(Deploy.nativeWrapper(output.moduleFactory, salt, WETH));

		if (stETH != address(0) || wstETH == address(0)) {
			output.stETHWrapper = address(Deploy.stETHWrapper(output.moduleFactory, salt, stETH, wstETH));
		}

		output.metaFactory.authorize(output.accountFactory);
		output.metaFactory.authorize(output.k1ValidatorFactory);
		output.metaFactory.authorize(output.registryFactory);
	}

	function constructJson(Deployments memory output) internal virtual {
		string memory deployments = "deployments";
		string memory item = "item";

		deployments = item.serialize(
			"Vortex",
			constructJson(output.vortex, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"Bootstrap",
			constructJson(output.bootstrap, output.deployer, output.salt, output.timestamp)
		);

		deployments = item.serialize(
			"MetaFactory",
			constructJson(address(output.metaFactory), output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"AccountFactory",
			constructJson(output.accountFactory, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"K1ValidatorFactory",
			constructJson(output.k1ValidatorFactory, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"RegistryFactory",
			constructJson(output.registryFactory, output.deployer, output.salt, output.timestamp)
		);

		deployments = item.serialize(
			"ModuleFactory",
			constructJson(address(output.moduleFactory), output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"K1Validator",
			constructJson(output.k1Validator, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"Permit2Executor",
			constructJson(output.permit2Executor, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"UniversalExecutor",
			constructJson(output.universalExecutor, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"NativeWrapper",
			constructJson(output.nativeWrapper, output.deployer, output.salt, output.timestamp)
		);
		deployments = item.serialize(
			"STETHWrapper",
			constructJson(output.stETHWrapper, output.deployer, output.salt, output.timestamp)
		);

		deployments.write(getDeploymentsPath(chainAlias()), ".deployments");
	}
}
