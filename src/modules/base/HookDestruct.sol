// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHook} from "src/interfaces/modules/IERC7579Modules.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATE} from "src/types/Constants.sol";
import {CallType, ModuleType} from "src/types/Types.sol";
import {TrustedForwarder} from "src/modules/utils/TrustedForwarder.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title HookDestruct

abstract contract HookDestruct is IHook, ModuleBase, TrustedForwarder {
	using CalldataDecoder for bytes;
	using ExecutionLib for bytes;

	/// @dev execute(bytes32,bytes)
	bytes4 internal constant EXECUTE_SELECTOR = 0xe9ae5c53;
	/// @dev executeFromExecutor(bytes32,bytes)
	bytes4 internal constant EXECUTE_FROM_EXECUTOR_SELECTOR = 0xd691c964;
	/// @dev executeUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes),bytes32)
	bytes4 internal constant EXECUTE_USER_OP_SELECTOR = 0x8dd7712f;
	/// @dev installModule(uint256,address,bytes)
	bytes4 internal constant INSTALL_MODULE_SELECTOR = 0x9517e29f;
	/// @dev uninstallModule(uint256,address,bytes)
	bytes4 internal constant UNINSTALL_MODULE_SELECTOR = 0xa71763a8;

	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) external payable virtual returns (bytes memory hookData) {
		bytes4 selector = msgData.decodeSelector();
		if (selector == EXECUTE_USER_OP_SELECTOR) {
			assembly ("memory-safe") {
				let ptr := add(msgData.offset, calldataload(add(msgData.offset, 0xa4)))
				msgData.length := calldataload(ptr)
				msgData.offset := add(ptr, 0x20)
			}

			selector = msgData.decodeSelector();
		}

		return _decodeCallData(selector, msgSender, msgValue, msgData);
	}

	function postCheck(bytes calldata hookData) external payable virtual {
		onPostCheck(_mapAccount(), hookData);
	}

	function _decodeCallData(
		bytes4 selector,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual returns (bytes memory hookData) {
		if (selector == EXECUTE_SELECTOR) {
			return _handleExecutions(_mapAccount(), msgSender, msgData[4:], false);
		} else if (selector == EXECUTE_FROM_EXECUTOR_SELECTOR) {
			return _handleExecutions(_mapAccount(), msgSender, msgData[4:], true);
		} else if (selector == INSTALL_MODULE_SELECTOR) {
			return _handleInstallations(_mapAccount(), msgSender, msgData[4:], true);
		} else if (selector == UNINSTALL_MODULE_SELECTOR) {
			return _handleInstallations(_mapAccount(), msgSender, msgData[4:], false);
		} else {
			return onUnknownFunction(_mapAccount(), msgSender, msgValue, msgData);
		}
	}

	function _handleExecutions(
		address account,
		address msgSender,
		bytes calldata msgData,
		bool fromExecutor
	) internal virtual returns (bytes memory hookData) {
		CallType callType;
		bytes calldata executionCalldata;

		assembly ("memory-safe") {
			callType := shl(0xf8, shr(0xf8, calldataload(msgData.offset)))

			// CALLTYPE_SINGLE: 0x00 | CALLTYPE_BATCH: 0x01 | CALLTYPE_DELEGATE: 0xFF
			if iszero(or(iszero(callType), or(eq(callType, shl(0xf8, 0x01)), eq(callType, shl(0xf8, 0xFF))))) {
				mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
				mstore(0x20, callType)
				revert(0x1c, 0x24)
			}

			let ptr := add(msgData.offset, calldataload(add(msgData.offset, 0x20)))
			executionCalldata.length := calldataload(ptr)
			executionCalldata.offset := add(ptr, 0x20)
		}

		if (callType == CALLTYPE_SINGLE) {
			(address target, uint256 value, bytes calldata callData) = executionCalldata.decodeSingle();

			hookData = !fromExecutor
				? onExecute(account, msgSender, target, value, callData)
				: onExecuteFromExecutor(account, msgSender, target, value, callData);
		} else if (callType == CALLTYPE_BATCH) {
			Execution[] calldata executions = executionCalldata.decodeBatch();

			hookData = !fromExecutor
				? onExecuteBatch(account, msgSender, executions)
				: onExecuteBatchFromExecutor(account, msgSender, executions);
		} else if (callType == CALLTYPE_DELEGATE) {
			(address target, bytes calldata callData) = executionCalldata.decodeDelegate();

			hookData = !fromExecutor
				? onExecuteDelegate(account, msgSender, target, callData)
				: onExecuteDelegateFromExecutor(account, msgSender, target, callData);
		}
	}

	function _handleInstallations(
		address account,
		address msgSender,
		bytes calldata msgData,
		bool isInstall
	) internal virtual returns (bytes memory hookData) {
		ModuleType moduleType;
		address module;

		assembly ("memory-safe") {
			moduleType := calldataload(msgData.offset)
			module := shr(0x60, shl(0x60, calldataload(add(msgData.offset, 0x20))))

			msgData.length := sub(msgData.length, 0x40)
			msgData.offset := add(msgData.offset, 0x40)

			if iszero(iszero(msgData.length)) {
				let ptr := add(msgData.offset, calldataload(msgData.offset))
				msgData.length := calldataload(ptr)
				msgData.offset := add(ptr, 0x20)
			}
		}

		hookData = isInstall
			? onInstallModule(account, msgSender, moduleType, module, msgData)
			: onUninstallModule(account, msgSender, moduleType, module, msgData);
	}

	function onExecute(
		address account,
		address msgSender,
		address target,
		uint256 value,
		bytes calldata callData
	) internal virtual returns (bytes memory hookData) {}

	function onExecuteBatch(
		address account,
		address msgSender,
		Execution[] calldata executions
	) internal virtual returns (bytes memory hookData) {}

	function onExecuteDelegate(
		address account,
		address msgSender,
		address target,
		bytes calldata callData
	) internal virtual returns (bytes memory hookData) {}

	function onExecuteFromExecutor(
		address account,
		address msgSender,
		address target,
		uint256 value,
		bytes calldata callData
	) internal virtual returns (bytes memory hookData) {}

	function onExecuteBatchFromExecutor(
		address account,
		address msgSender,
		Execution[] calldata executions
	) internal virtual returns (bytes memory hookData) {}

	function onExecuteDelegateFromExecutor(
		address account,
		address msgSender,
		address target,
		bytes calldata callData
	) internal virtual returns (bytes memory hookData) {}

	function onInstallModule(
		address account,
		address msgSender,
		ModuleType moduleType,
		address module,
		bytes calldata data
	) internal virtual returns (bytes memory hookData) {}

	function onUninstallModule(
		address account,
		address msgSender,
		ModuleType moduleType,
		address module,
		bytes calldata data
	) internal virtual returns (bytes memory hookData) {}

	function onUnknownFunction(
		address account,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual returns (bytes memory hookData) {}

	function onPostCheck(address account, bytes calldata hookData) internal virtual {}
}
