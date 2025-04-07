// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {Deploy, STETHWrapper} from "test/shared/utils/Deploy.sol";

contract DeploySTETHWrapper is BaseScript {
	using stdJson for string;

	function run() public returns (STETHWrapper stETHWrapper) {
		uint256 chainId = block.chainid;
		address stETH;
		address wstETH;

		if (chainId == ETHEREUM_CHAIN_ID) {
			stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
			wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
		} else if (chainId == SEPOLIA_CHAIN_ID) {
			stETH = 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
			wstETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
		} else {
			revert UnsupportedChain(chainId);
		}

		bytes32 salt = getContractSalt("STETHWrapper");
		stETHWrapper = Deploy.stETHWrapper(getModuleFactory(), salt, stETH, wstETH);

		string memory output = "deployment";
		output = constructJson(address(stETHWrapper), broadcaster, salt, vm.getBlockTimestamp());
		output.write(getDeploymentsPath(chainAlias()), ".deployments.STETHWrapper");
	}
}
