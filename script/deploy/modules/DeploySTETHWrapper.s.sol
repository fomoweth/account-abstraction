// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, STETHWrapper} from "test/shared/utils/Deploy.sol";

contract DeploySTETHWrapper is BaseScript {
	using stdJson for string;

	function run() public returns (STETHWrapper stETHWrapper) {
		bytes32 salt = getContractSalt("STETHWrapper");
		stETHWrapper = Deploy.stETHWrapper(getMetaFactory(), salt, stETH(), wstETH());

		string memory output = "deployment";
		output = constructJson(address(stETHWrapper), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.STETHWrapper");
	}
}
