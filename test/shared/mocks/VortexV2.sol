// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {Vortex} from "src/Vortex.sol";

address constant ENTRYPOINT_V8 = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

contract VortexV2 is Vortex {
	using AccountIdLib for string;

	function entryPoint() public pure virtual override returns (address) {
		return ENTRYPOINT_V8;
	}

	function accountId() public pure virtual override returns (string memory) {
		return "fomoweth.vortex.2.0.0";
	}

	function _domainNameAndVersion()
		internal
		view
		virtual
		override
		returns (string memory name, string memory version)
	{
		return accountId().parse();
	}
}
