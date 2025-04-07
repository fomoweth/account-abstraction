// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {Deploy, AccountFactory} from "test/shared/utils/Deploy.sol";

contract DeployAccountFactory is BaseScript {
	using stdJson for string;

	function run() public returns (AccountFactory factory) {
		bytes32 salt = getContractSalt("AccountFactory");
		factory = Deploy.accountFactory(salt, getAddress("Vortex"));

		string memory output = "deployment";
		output = constructJson(address(factory), broadcaster, salt, vm.getBlockTimestamp());
		output.write(getDeploymentsPath(chainAlias()), ".deployments.AccountFactory");
	}
}
