// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vortex} from "src/Vortex.sol";

contract VortexV2 is Vortex {
	function accountId() public pure virtual override returns (string memory) {
		return "fomoweth.vortex.2.0.0";
	}

	function entryPoint() public pure virtual override returns (address) {
		return 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
	}
}
