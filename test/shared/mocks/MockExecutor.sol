// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISmartAccount, Execution} from "src/interfaces/ISmartAccount.sol";
import {IExecutor} from "src/interfaces/IERC7579Modules.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";
import {SmartAccount} from "src/SmartAccount.sol";

contract MockExecutor is IExecutor, ModuleBase {
	mapping(address account => bool isInstalled) public isInstalled;

	function executeViaAccount(
		SmartAccount account,
		address target,
		uint256 value,
		bytes calldata callData
	) public returns (bytes[] memory results) {
		return account.executeFromExecutor(ExecutionModeLib.encodeSingle(), abi.encodePacked(target, value, callData));
	}

	function tryExecuteViaAccount(
		SmartAccount account,
		address target,
		uint256 value,
		bytes calldata callData
	) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));
		return
			account.executeFromExecutor(ExecutionModeLib.encodeTrySingle(), abi.encodePacked(target, value, callData));
	}

	function executeBatchViaAccount(
		SmartAccount account,
		Execution[] calldata executions
	) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));
		return account.executeFromExecutor(ExecutionModeLib.encodeBatch(), abi.encode(executions));
	}

	function tryExecuteBatchViaAccount(
		SmartAccount account,
		Execution[] calldata executions
	) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));
		return account.executeFromExecutor(ExecutionModeLib.encodeTryBatch(), abi.encode(executions));
	}

	function executeDelegate(SmartAccount account, bytes calldata callData) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));
		return account.executeFromExecutor(ExecutionModeLib.encodeDelegate(), callData);
	}

	function tryExecuteDelegate(SmartAccount account, bytes calldata callData) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));
		return account.executeFromExecutor(ExecutionModeLib.encodeTryDelegate(), callData);
	}

	function customExecuteViaAccount(
		SmartAccount account,
		ExecutionMode mode,
		address target,
		uint256 value,
		bytes calldata callData
	) public returns (bytes[] memory results) {
		if (!isInitialized(address(account))) revert NotInitialized(address(account));

		(CallType callType, ) = ExecutionModeLib.decodeBasic(mode);

		bytes memory executionCallData;

		if (callType == ExecutionModeLib.CALLTYPE_SINGLE) {
			executionCallData = abi.encodePacked(target, value, callData);
		} else if (callType == ExecutionModeLib.CALLTYPE_BATCH) {
			Execution[] memory execution = new Execution[](1);
			execution[0] = Execution(target, value, callData);
			executionCallData = abi.encode(execution);
		} else if (callType == ExecutionModeLib.CALLTYPE_DELEGATE) {
			executionCallData = abi.encodePacked(target, callData);
		}

		return account.executeFromExecutor(mode, executionCallData);
	}

	function onInstall(bytes calldata data) public payable {
		if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);
		data;
		isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) public payable {
		if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
		isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) public view returns (bool) {
		return isInstalled[account];
	}

	function name() public pure returns (string memory) {
		return "MockExecutor";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(uint256 moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_EXECUTOR;
	}

	receive() external payable {}
}
