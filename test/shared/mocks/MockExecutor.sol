// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "src/interfaces/IERC7579Modules.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATE, MODULE_TYPE_EXECUTOR} from "src/types/Constants.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockExecutor is IExecutor, ModuleBase {
	struct Execution {
		address target;
		uint256 value;
		bytes callData;
	}

	mapping(address account => bool isInstalled) public isInstalled;

	function executeViaAccount(
		address account,
		address target,
		uint256 value,
		bytes calldata callData
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return IERC7579Account(account).executeFromExecutor(mode, executionCalldata);
	}

	function tryExecuteViaAccount(
		address account,
		address target,
		uint256 value,
		bytes calldata callData
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeTrySingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return IERC7579Account(account).executeFromExecutor(mode, executionCalldata);
	}

	function executeBatchViaAccount(
		address account,
		Execution[] calldata executions
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeBatch();
		bytes memory executionCalldata = abi.encode(executions);

		return IERC7579Account(account).executeFromExecutor(mode, executionCalldata);
	}

	function tryExecuteBatchViaAccount(
		address account,
		Execution[] calldata executions
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeTryBatch();
		bytes memory executionCalldata = abi.encode(executions);

		return IERC7579Account(account).executeFromExecutor(mode, executionCalldata);
	}

	function executeDelegate(address account, bytes calldata callData) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeDelegate();

		return IERC7579Account(account).executeFromExecutor(mode, callData);
	}

	function tryExecuteDelegate(
		address account,
		bytes calldata callData
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		ExecutionMode mode = ExecutionModeLib.encodeTryDelegate();

		return IERC7579Account(account).executeFromExecutor(mode, callData);
	}

	function customExecuteViaAccount(
		address account,
		ExecutionMode mode,
		address target,
		uint256 value,
		bytes calldata callData
	) public payable returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		CallType callType = mode.parseCallType();

		bytes memory executionCalldata;

		if (callType == CALLTYPE_SINGLE) {
			executionCalldata = abi.encodePacked(target, value, callData);
		} else if (callType == CALLTYPE_BATCH) {
			Execution[] memory execution = new Execution[](1);
			execution[0] = Execution(target, value, callData);
			executionCalldata = abi.encode(execution);
		} else if (callType == CALLTYPE_DELEGATE) {
			executionCalldata = abi.encodePacked(target, callData);
		}

		return IERC7579Account(account).executeFromExecutor(mode, executionCalldata);
	}

	function onInstall(bytes calldata) public payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) public payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		isInstalled[msg.sender] = false;
	}

	function name() public pure virtual override returns (string memory) {
		return "MockExecutor";
	}

	function version() public pure virtual override returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_EXECUTOR;
	}

	function _isInitialized(address account) internal view virtual override returns (bool) {
		return isInstalled[account];
	}

	receive() external payable {}
}
