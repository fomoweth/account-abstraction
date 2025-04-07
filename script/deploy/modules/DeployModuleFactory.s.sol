// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {Deploy, ModuleFactory} from "test/shared/utils/Deploy.sol";

contract DeployModuleFactory is BaseScript {
	using stdJson for string;

	function run() external broadcast returns (ModuleFactory factory) {
		bytes32 salt = getContractSalt("ModuleFactory");
		factory = Deploy.moduleFactory(salt, address(REGISTRY), RESOLVER_UID);

		string memory output = "deployment";
		output = constructJson(address(factory), broadcaster, salt, vm.getBlockTimestamp());
		output.write(getDeploymentsPath(chainAlias()), ".deployments.ModuleFactory");
	}
}
