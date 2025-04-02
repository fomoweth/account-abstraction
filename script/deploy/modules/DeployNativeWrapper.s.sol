// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/deploy/BaseScript.s.sol";
import {Deploy, NativeWrapper} from "test/shared/utils/Deploy.sol";

contract DeployNativeWrapper is BaseScript {
	using stdJson for string;

	function run() public returns (NativeWrapper nativeWrapper) {
		bytes32 salt = getContractSalt("NativeWrapper");
		nativeWrapper = Deploy.nativeWrapper(getMetaFactory(), salt, wrappedNative());

		string memory output = "deployment";
		output = constructJson(address(nativeWrapper), broadcaster, salt);
		output.write(getDeploymentsPath(chainAlias()), ".deployments.NativeWrapper");
	}
}
