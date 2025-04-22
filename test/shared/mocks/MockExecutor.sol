// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "src/interfaces/IERC7579Modules.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {ExecutionModeLib, ExecutionMode} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/base/ModuleBase.sol";
import {Vortex} from "src/Vortex.sol";

contract MockExecutor is IExecutor, ModuleBase {
	mapping(address account => bool isInstalled) internal _isInstalled;

	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function executeViaAccount(
		Vortex account,
		address target,
		uint256 value,
		bytes calldata callData
	) external returns (bytes memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return account.executeFromExecutor(mode, executionCalldata)[0];
	}

	function executeDelegateViaAccount(
		Vortex account,
		address target,
		bytes calldata callData
	) external returns (bytes memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeDelegate();
		bytes memory executionCalldata = abi.encodePacked(target, callData);

		return account.executeFromExecutor(mode, executionCalldata)[0];
	}

	function executeBatchViaAccount(
		Vortex account,
		Execution[] calldata executions
	) external returns (bytes[] memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeBatch();
		bytes memory executionCalldata = abi.encode(executions);

		return account.executeFromExecutor(mode, executionCalldata);
	}

	function tryExecuteViaAccount(
		Vortex account,
		address target,
		uint256 value,
		bytes calldata callData
	) external returns (bytes memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeTrySingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return account.executeFromExecutor(mode, executionCalldata)[0];
	}

	function tryExecuteDelegateViaAccount(
		Vortex account,
		address target,
		bytes calldata callData
	) external returns (bytes memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeTryDelegate();
		bytes memory executionCalldata = abi.encodePacked(target, callData);

		return account.executeFromExecutor(mode, executionCalldata)[0];
	}

	function tryExecuteBatchViaAccount(
		Vortex account,
		Execution[] calldata executions
	) external returns (bytes[] memory returnData) {
		ExecutionMode mode = ExecutionModeLib.encodeTryBatch();
		bytes memory executionCalldata = abi.encode(executions);

		return account.executeFromExecutor(mode, executionCalldata);
	}

	function name() external pure returns (string memory) {
		return "MockExecutor";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_EXECUTOR;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _isInstalled[account];
	}
}
