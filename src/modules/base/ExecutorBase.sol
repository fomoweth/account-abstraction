// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "src/interfaces/IERC7579Modules.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title ExecutorBase

abstract contract ExecutorBase is IExecutor, ModuleBase {
	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	function _execute(
		address target,
		uint256 value,
		bytes memory callData
	) internal virtual returns (bytes[] memory returnData) {
		return _execute(msg.sender, target, value, callData);
	}

	function _execute(
		address account,
		address target,
		uint256 value,
		bytes memory callData
	) internal virtual returns (bytes[] memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return IERC7579Account(account).executeFromExecutor{value: msg.value}(mode, executionCalldata);
	}

	function _execute(address target, bytes memory callData) internal virtual returns (bytes[] memory returnData) {
		return _execute(msg.sender, target, callData);
	}

	function _execute(
		address account,
		address target,
		bytes memory callData
	) internal virtual returns (bytes[] memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeDelegate();
		bytes memory executionCalldata = abi.encodePacked(target, callData);

		return IERC7579Account(account).executeFromExecutor{value: msg.value}(mode, executionCalldata);
	}

	function _execute(Execution[] memory executions) internal virtual returns (bytes[] memory returnData) {
		return _execute(msg.sender, executions);
	}

	function _execute(
		address account,
		Execution[] memory executions
	) internal virtual returns (bytes[] memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeBatch();
		bytes memory executionCalldata = abi.encode(executions);

		return IERC7579Account(account).executeFromExecutor{value: msg.value}(mode, executionCalldata);
	}

	// function _executeFromExecutor(
	// 	address account,
	// 	ExecutionMode mode,
	// 	bytes memory executionCalldata
	// ) internal virtual returns (bytes[] memory returnData) {
	// 	return IERC7579Account(account).executeFromExecutor{value: msg.value}(mode, executionCalldata);
	// }
}
