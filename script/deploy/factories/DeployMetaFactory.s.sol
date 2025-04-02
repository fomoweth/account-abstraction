// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, MetaFactory} from "test/shared/utils/Deploy.sol";

contract DeployMetaFactory is BaseScript {
	using stdJson for string;

	function run() public returns (MetaFactory factory) {
		bytes32 salt = getContractSalt("MetaFactory");
		factory = Deploy.metaFactory(salt, broadcaster);

		string memory output = "deployment";
		output = constructJson(address(factory), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.MetaFactory");
	}
}
