// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {Deploy, NativeWrapper} from "test/shared/utils/Deploy.sol";

contract DeployNativeWrapper is BaseScript {
	using stdJson for string;

	function run() public returns (NativeWrapper nativeWrapper) {
		bytes32 salt = getContractSalt("NativeWrapper");
		nativeWrapper = Deploy.nativeWrapper(getModuleFactory(), salt, wrappedNative());

		string memory output = "output";
		output = constructJson(address(nativeWrapper), broadcaster, salt, vm.getBlockTimestamp());
		output.write(getDeploymentsPath(chainAlias()), ".deployments.NativeWrapper");
	}
}
