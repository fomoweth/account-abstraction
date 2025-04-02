// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {Deploy} from "test/shared/utils/Deploy.sol";
import {BaseScript} from "./BaseScript.s.sol";

contract DeployAll is BaseScript {
	using stdJson for string;

	function run() public broadcast {
		string memory deployments = "deployments";
		string memory item = "item";

		address deployer = broadcaster;
		bytes32 salt;

		salt = getContractSalt("MetaFactory");
		MetaFactory metaFactory = Deploy.metaFactory(salt, deployer);
		deployments = item.serialize("MetaFactory", constructJson(address(metaFactory), deployer, salt));

		salt = getContractSalt("Vortex");
		address vortex = address(Deploy.vortex(salt));
		deployments = item.serialize("Vortex", constructJson(vortex, deployer, salt));

		salt = getContractSalt("Bootstrap");
		address bootstrap = address(Deploy.bootstrap(salt));
		deployments = item.serialize("Bootstrap", constructJson(bootstrap, deployer, salt));

		salt = getContractSalt("K1Validator");
		address k1Validator = address(Deploy.k1Validator(salt));
		deployments = item.serialize("K1Validator", constructJson(k1Validator, deployer, salt));

		salt = getContractSalt("AccountFactory");
		address accountFactory = address(Deploy.accountFactory(salt, vortex));
		deployments = item.serialize("AccountFactory", constructJson(accountFactory, deployer, salt));

		salt = getContractSalt("K1ValidatorFactory");
		address k1ValidatorFactory = address(Deploy.k1ValidatorFactory(salt, vortex, bootstrap, k1Validator));
		deployments = item.serialize("K1ValidatorFactory", constructJson(k1ValidatorFactory, deployer, salt));

		salt = getContractSalt("RegistryFactory");
		address registryFactory = address(Deploy.registryFactory(salt, vortex, bootstrap, address(REGISTRY), deployer));
		deployments = item.serialize("RegistryFactory", constructJson(registryFactory, deployer, salt));

		metaFactory.authorize(accountFactory);
		metaFactory.authorize(k1ValidatorFactory);
		metaFactory.authorize(registryFactory);

		salt = getContractSalt("Permit2Executor");
		address permit2Executor = address(Deploy.permit2Executor(salt));
		deployments = item.serialize("Permit2Executor", constructJson(permit2Executor, deployer, salt));

		salt = getContractSalt("UniversalExecutor");
		address universalExecutor = address(Deploy.universalExecutor(metaFactory, salt, wrappedNative()));
		deployments = item.serialize("UniversalExecutor", constructJson(universalExecutor, deployer, salt));

		salt = getContractSalt("NativeWrapper");
		address nativeWrapper = address(Deploy.nativeWrapper(metaFactory, salt, wrappedNative()));
		deployments = item.serialize("NativeWrapper", constructJson(nativeWrapper, deployer, salt));

		if (isEthereum() || isSepolia()) {
			salt = getContractSalt("STETHWrapper");
			address stETHWrapper = address(Deploy.stETHWrapper(metaFactory, salt, stETH(), wstETH()));
			deployments = item.serialize("STETHWrapper", constructJson(stETHWrapper, deployer, salt));
		} else {
			deployments = item.serialize("STETHWrapper", constructJson(address(0), address(0), bytes32(0)));
		}

		deployments.write(getDeploymentsPath(chainAlias()), ".deployments");
	}
}
