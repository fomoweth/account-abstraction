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

	error LengthMismatch();

	error SliceOutOfBounds();

	// ERC-7579 ModuleManager
	error InvalidModule();
	error InvalidModuleTypeId(ModuleType moduleTypeId);
	error UnsupportedModuleType(ModuleType moduleTypeId);

	error ModuleAlreadyInstalled(address module);
	error ModuleNotInstalled(address module);

	// ERC-7579 Executor
	error ExecutionFailed();

	error UnsupportedCallType(CallType callType);
	error UnsupportedExecType(ExecType execType);

	error InvalidCallType();
	error InvalidExecType();

	// ERC-7579 Fallback
	error InvalidSelector();
	error UnknownSelector(bytes4 selector);

	// ERC-7579 Modules
	error AlreadyInitialized(address account);
	error NotInitialized(address account);
}
