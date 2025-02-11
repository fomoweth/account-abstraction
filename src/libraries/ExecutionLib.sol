// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecType, EXECTYPE_DEFAULT, EXECTYPE_TRY} from "src/types/ExecutionMode.sol";

struct Execution {
	address target;
	uint256 value;
	bytes callData;
}

/// @title ExecutionLib
/// @notice Provides functions to handle executions for smart account

library ExecutionLib {
	event TryExecuteUnsuccessful(uint256 index, bytes returnData);

	function executeSingle(
		bytes calldata executionCalldata,
		ExecType execType
	) internal returns (bytes[] memory returnData) {
		(address target, uint256 value, bytes calldata callData) = decodeSingle(executionCalldata);

		returnData = new bytes[](1);
		returnData[0] = _validateExecution(0, execType, _call(target, value, callData));
	}

	function executeBatch(
		bytes calldata executionCalldata,
		ExecType execType
	) internal returns (bytes[] memory returnData) {
		Execution[] calldata executions = decodeBatch(executionCalldata);
		Execution calldata execution;

		uint256 length = executions.length;
		returnData = new bytes[](length);

		for (uint256 i; i < length; ) {
			execution = executions[i];
			returnData[i] = _validateExecution(
				i,
				execType,
				_call(execution.target, execution.value, execution.callData)
			);

			unchecked {
				i = i + 1;
			}
		}
	}

	function executeDelegate(
		bytes calldata executionCalldata,
		ExecType execType
	) internal returns (bytes[] memory returnData) {
		(address target, bytes calldata callData) = decodeDelegate(executionCalldata);
		returnData = new bytes[](1);
		returnData[0] = _validateExecution(0, execType, _delegatecall(target, callData));
	}

	function decodeSingle(
		bytes calldata executionCalldata
	) internal pure returns (address target, uint256 value, bytes calldata callData) {
		assembly ("memory-safe") {
			if iszero(gt(executionCalldata.length, 0x33)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			target := shr(0x60, calldataload(executionCalldata.offset))
			value := calldataload(add(executionCalldata.offset, 0x14))
			callData.offset := add(executionCalldata.offset, 0x34)
			callData.length := sub(executionCalldata.length, 0x34)
		}
	}

	function decodeBatch(bytes calldata executionCalldata) internal pure returns (Execution[] calldata executions) {
		assembly ("memory-safe") {
			let u := calldataload(executionCalldata.offset)
			let s := add(executionCalldata.offset, u)
			let e := sub(add(executionCalldata.offset, executionCalldata.length), 0x20)

			executions.offset := add(s, 0x20)
			executions.length := calldataload(s)

			if or(shr(0x40, u), gt(add(s, shl(0x05, executions.length)), e)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			// prettier-ignore
			if executions.length {
				for { let i := executions.length } 0x01 { } {
					i := sub(i, 0x01)
					let p := calldataload(add(executions.offset, shl(0x05, i)))
					let c := add(executions.offset, p)
					let q := calldataload(add(c, 0x40))
					let o := add(c, q)

					if or(shr(0x40, or(calldataload(o), or(p, q))),
						or(gt(add(c, 0x40), e), gt(add(o, calldataload(o)), e))) {
						mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
						revert(0x1c, 0x04)
					}
					if iszero(i) { break }
				}
			}
		}
	}

	function decodeDelegate(
		bytes calldata executionCalldata
	) internal pure returns (address target, bytes calldata callData) {
		assembly ("memory-safe") {
			if iszero(gt(executionCalldata.length, 0x13)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			target := shr(0x60, calldataload(executionCalldata.offset))
			callData.offset := add(executionCalldata.offset, 0x14)
			callData.length := sub(executionCalldata.length, 0x14)
		}
	}

	function encodeSingle(address target, uint256 value, bytes memory callData) internal pure returns (bytes memory) {
		return abi.encodePacked(target, value, callData);
	}

	function encodeBatch(Execution[] memory executions) internal pure returns (bytes memory) {
		return abi.encode(executions);
	}

	function encodeDelegate(address target, bytes memory callData) internal pure returns (bytes memory) {
		return abi.encodePacked(target, callData);
	}

	function _call(address target, uint256 value, bytes memory data) private returns (bool success) {
		assembly ("memory-safe") {
			success := call(gas(), target, value, add(data, 0x20), mload(data), codesize(), 0x00)
		}
	}

	function _delegatecall(address target, bytes memory data) private returns (bool success) {
		assembly ("memory-safe") {
			success := delegatecall(gas(), target, add(data, 0x20), mload(data), codesize(), 0x00)
		}
	}

	function _staticcall(address target, bytes memory data) private view returns (bool success) {
		assembly ("memory-safe") {
			success := staticcall(gas(), target, add(data, 0x20), mload(data), codesize(), 0x00)
		}
	}

	function _validateExecution(
		uint256 index,
		ExecType execType,
		bool success
	) private returns (bytes memory returnData) {
		assembly ("memory-safe") {
			returnData := mload(0x40)

			if and(iszero(success), iszero(execType)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0xacfdb444) // ExecutionFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(returnData, 0x00, returndatasize())
				revert(returnData, returndatasize())
			}

			mstore(0x40, add(add(returnData, 0x20), returndatasize()))
			mstore(returnData, returndatasize())
			returndatacopy(add(returnData, 0x20), 0x00, returndatasize())
		}

		if (!success) emit TryExecuteUnsuccessful(index, returnData);
	}
}
