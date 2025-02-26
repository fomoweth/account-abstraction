// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType, ExecType, ModuleType} from "src/types/Types.sol";

/// @title Errors
/// @notice Contains all custom error messages used in Vortex

library Errors {
	// Common
	error EmptyCode();

	error InvalidInitialization();
	error InitializationFailed();

	error InvalidSignature();
	error InvalidDataLength();

	error ExceededMaxLimit();
	error LengthMismatch();
	error NotSorted();

	error SliceOutOfBounds();

	// ERC-7579 ModuleManager
	error InvalidModule();
	error InvalidModuleType();
	error InvalidModuleTypeId();
	error UnsupportedModuleType(ModuleType moduleTypeId);

	error ModuleAlreadyInstalled(address module);
	error ModuleNotInstalled(address module);

	// ERC-7579 Executor
	error ExecutionFailed();

	error UnsupportedCallType(CallType callType);
	error UnsupportedExecType(ExecType execType);

	error InvalidCallType();
	error InvalidExecType();
	error InvalidFlag();

	// ERC-7579 Fallback
	error Forbidden();
	error ForbiddenFallback();
	error InvalidSelector();
	error UnknownSelector(bytes4 selector);
	error IntegrityCheckFailed();

	// ERC-7579 Modules
	error AlreadyInitialized(address account);
	error NotInitialized(address account);
}
