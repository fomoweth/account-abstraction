// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, Permit2Executor} from "test/shared/utils/Deploy.sol";

contract DeployPermit2Executor is BaseScript {
	using stdJson for string;

	function run() public returns (Permit2Executor executor) {
		bytes32 salt = getContractSalt("Permit2Executor");
		executor = Deploy.permit2Executor(salt);

		string memory output = "deployment";
		output = constructJson(address(executor), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.Permit2Executor");
	}
}
