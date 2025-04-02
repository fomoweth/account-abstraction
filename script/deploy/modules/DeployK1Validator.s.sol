// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, K1Validator} from "test/shared/utils/Deploy.sol";

contract DeployK1Validator is BaseScript {
	using stdJson for string;

	function run() public returns (K1Validator k1Validator) {
		bytes32 salt = getContractSalt("K1Validator");
		k1Validator = Deploy.k1Validator(salt);

		string memory output = "deployment";
		output = constructJson(address(k1Validator), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.K1Validator");
	}
}
