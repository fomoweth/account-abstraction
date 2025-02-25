// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/modules/IERC7579Modules.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK, MODULE_TYPE_POLICY, MODULE_TYPE_SIGNER, MODULE_TYPE_STATELESS_VALIDATOR} from "src/types/ModuleType.sol";

/// @title ModuleBase

abstract contract ModuleBase is IModule {
	error InvalidDataLength();
	error UnsupportedExecution();
	error UnsupportedOperation();

	ModuleType internal constant TYPE_VALIDATOR = MODULE_TYPE_VALIDATOR;
	ModuleType internal constant TYPE_EXECUTOR = MODULE_TYPE_EXECUTOR;
	ModuleType internal constant TYPE_FALLBACK = MODULE_TYPE_FALLBACK;
	ModuleType internal constant TYPE_HOOK = MODULE_TYPE_HOOK;
	ModuleType internal constant TYPE_POLICY = MODULE_TYPE_POLICY;
	ModuleType internal constant TYPE_SIGNER = MODULE_TYPE_SIGNER;
	ModuleType internal constant TYPE_STATELESS_VALIDATOR = MODULE_TYPE_STATELESS_VALIDATOR;
}
