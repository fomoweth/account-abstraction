// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/IERC7579Modules.sol";
import {ModuleType} from "src/types/ModuleType.sol";

/// @title ModuleBase
/// @notice ERC-7579 module base interface
abstract contract ModuleBase is IModule {
	/// @notice Thrown when the requested execution type is not supported by the module
	error UnsupportedExecution();

	/// @notice Thrown when the requested operation is not supported by the module
	error UnsupportedOperation();

	ModuleType internal constant MODULE_TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant MODULE_TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant MODULE_TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant MODULE_TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant MODULE_TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant MODULE_TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant MODULE_TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);
}
