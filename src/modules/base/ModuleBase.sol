// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/IERC7579Modules.sol";
import {ModuleType} from "src/types/ModuleType.sol";

/// @title ModuleBase

abstract contract ModuleBase is IModule {
	error InvalidDataLength();
	error UnsupportedExecution();
	error UnsupportedOperation();

	ModuleType internal constant TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);
}
