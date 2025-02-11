// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "src/interfaces/modules/IERC7579Modules.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATE, MODULE_TYPE_EXECUTOR} from "src/types/Constants.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockExecutor is IExecutor, ModuleBase {
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

	function _executeFromExecutor(
		address account,
		ExecutionMode mode,
		bytes calldata executionCallData
	) internal virtual returns (bytes[] memory results) {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd691c96400000000000000000000000000000000000000000000000000000000) // executeFromExecutor(bytes32,bytes)
			mstore(add(ptr, 0x04), mode)
			mstore(add(ptr, 0x24), executionCallData.length)
			calldatacopy(add(ptr, 0x44), executionCallData.offset, executionCallData.length)

			let success := call(gas(), account, callvalue(), ptr, add(executionCallData.length, 0x44), 0x00, 0x00)

			returndatacopy(ptr, 0x00, returndatasize())
			// prettier-ignore
			if iszero(success) { revert(ptr, returndatasize()) }

			mstore(0x40, add(results, returndatasize()))

			let length := div(sub(returndatasize(), 0x40), 0x20)
			let offset := add(results, 0x20)
			let guard := add(offset, shl(0x05, length))
			ptr := sub(add(ptr, 0x40), offset)
			mstore(results, length)

			// prettier-ignore
			for { } 0x01 { } {
				mstore(offset, mload(add(ptr, offset)))
				offset := add(offset, 0x20)
				if eq(offset, guard) { break }
			}

			mstore(0x40, guard)
		}
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
