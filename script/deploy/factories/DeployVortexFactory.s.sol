// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {Deploy, K1ValidatorFactory} from "test/shared/utils/Deploy.sol";

contract DeployK1ValidatorFactory is BaseScript {
	using stdJson for string;

	function run() public returns (K1ValidatorFactory factory) {
		bytes32 salt = getContractSalt("K1ValidatorFactory");
		factory = Deploy.k1ValidatorFactory(
			salt,
			getAddress("Vortex"),
			getAddress("Bootstrap"),
			getAddress("K1Validator")
		);

		string memory output = "deployment";
		output = constructJson(address(factory), broadcaster, salt, vm.getBlockTimestamp());
		output.write(getDeploymentsPath(chainAlias()), ".deployments.K1ValidatorFactory");
	}
}
