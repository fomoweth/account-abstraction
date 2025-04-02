// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, RegistryFactory} from "test/shared/utils/Deploy.sol";

contract DeployRegistryFactory is BaseScript {
	using stdJson for string;

	function run() public returns (RegistryFactory factory) {
		bytes32 salt = getContractSalt("RegistryFactory");
		factory = Deploy.registryFactory(
			salt,
			getAddress("Vortex"),
			getAddress("Bootstrap"),
			address(REGISTRY),
			broadcaster
		);

		string memory output = "deployment";
		output = constructJson(address(factory), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.RegistryFactory");

		getMetaFactory().authorize(address(factory));
	}
}
