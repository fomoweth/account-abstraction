// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, UniversalExecutor} from "test/shared/utils/Deploy.sol";

contract DeployUniversalExecutor is BaseScript {
	using stdJson for string;

	function run() public returns (UniversalExecutor executor) {
		bytes32 salt = getContractSalt("UniversalExecutor");
		executor = Deploy.universalExecutor(getMetaFactory(), salt, wrappedNative());

		string memory output = "deployment";
		output = constructJson(address(executor), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.UniversalExecutor");
	}
}
