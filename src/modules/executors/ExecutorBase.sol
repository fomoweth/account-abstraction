// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "src/interfaces/IERC7579Modules.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {ExecutionModeLib} from "src/types/ExecutionMode.sol";
import {ModuleType, MODULE_TYPE_EXECUTOR} from "src/types/ModuleType.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title ExecutorBase

abstract contract ExecutorBase is IExecutor, ModuleBase {
	function _executeSingle(
		address account,
		address target,
		uint256 value,
		bytes memory callData
	) internal virtual returns (bytes memory result) {
		result = IERC7579Account(account).executeFromExecutor{value: value}(
			ExecutionModeLib.encodeSingle(),
			abi.encodePacked(target, value, callData)
		)[0];
	}

	function _executeSingle(
		address target,
		uint256 value,
		bytes memory callData
	) internal virtual returns (bytes memory result) {
		result = _executeSingle(msg.sender, target, value, callData);
	}

	function _executeBatch(
		address account,
		Execution[] memory executions
	) internal virtual returns (bytes[] memory results) {
		results = IERC7579Account(account).executeFromExecutor{value: msg.value}(
			ExecutionModeLib.encodeBatch(),
			abi.encode(executions)
		);
	}

	function _executeBatch(Execution[] memory executions) internal virtual returns (bytes[] memory results) {
		results = _executeBatch(msg.sender, executions);
	}

	function _executeDelegate(
		address account,
		address target,
		bytes memory callData
	) internal virtual returns (bytes[] memory results) {
		results = IERC7579Account(account).executeFromExecutor(
			ExecutionModeLib.encodeDelegate(),
			abi.encodePacked(target, callData)
		);
	}

	function _executeDelegate(address target, bytes memory callData) internal virtual returns (bytes[] memory results) {
		return _executeDelegate(msg.sender, target, callData);
	}

	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_EXECUTOR;
	}
}
