// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/IERC7579Modules.sol";

/// @title ModuleBase

abstract contract ModuleBase is IModule {
	error InvalidDataLength();

	uint256 internal constant MODULE_TYPE_MULTI = 0;
	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;
}
