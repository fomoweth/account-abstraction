// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {CustomRevert} from "./CustomRevert.sol";

struct Execution {
	address target;
	uint256 value;
	bytes callData;
}

/// @title ExecutionLib
/// @notice Provides functions to handle executions for smart account

library ExecutionLib {
	using CustomRevert for bytes4;

	event TryExecuteUnsuccessful(bytes callData, bytes result);
	event TryDelegateCallUnsuccessful(bytes callData, bytes result);

	error UnsupportedCallType();
	error UnsupportedExecType();

	function execute(ExecutionMode mode, bytes calldata executionData) internal returns (bytes[] memory results) {
		(CallType callType, ExecType execType) = mode.decodeBasic();

		if (callType == ExecutionModeLib.CALLTYPE_BATCH) {
			if (execType == ExecutionModeLib.EXECTYPE_DEFAULT) {
				results = executeBatch(decodeBatch(executionData));
			} else if (execType == ExecutionModeLib.EXECTYPE_TRY) {
				results = tryExecuteBatch(decodeBatch(executionData));
			} else {
				UnsupportedExecType.selector.revertWith();
			}
		} else {
			results = new bytes[](1);

			if (callType == ExecutionModeLib.CALLTYPE_SINGLE) {
				(address target, uint256 value, bytes calldata callData) = decodeSingle(executionData);

				if (execType == ExecutionModeLib.EXECTYPE_DEFAULT) {
					results[0] = executeSingle(target, value, callData);
				} else if (execType == ExecutionModeLib.EXECTYPE_TRY) {
					(, results[0]) = tryExecuteSingle(target, value, callData);
				} else {
					UnsupportedExecType.selector.revertWith();
				}
			} else if (callType == ExecutionModeLib.CALLTYPE_DELEGATE) {
				(address target, bytes calldata callData) = decodeDelegate(executionData);

				if (execType == ExecutionModeLib.EXECTYPE_DEFAULT) {
					results[0] = executeDelegate(target, callData);
				} else if (execType == ExecutionModeLib.EXECTYPE_TRY) {
					(, results[0]) = tryExecuteDelegate(target, callData);
				} else {
					UnsupportedExecType.selector.revertWith();
				}
			} else {
				UnsupportedCallType.selector.revertWith();
			}
		}
	}

	function executeSingle(
		address target,
		uint256 value,
		bytes calldata callData
	) internal returns (bytes memory result) {
		assembly ("memory-safe") {
			result := mload(0x40)
			calldatacopy(result, callData.offset, callData.length)

			if iszero(call(gas(), target, value, result, callData.length, codesize(), 0x00)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0xacfdb444) // ExecutionFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(result, 0x00, returndatasize())
				revert(result, returndatasize())
			}

			mstore(result, returndatasize())
			returndatacopy(add(result, 0x20), 0x00, returndatasize())
			mstore(0x40, add(add(result, 0x20), returndatasize()))
		}
	}

	function tryExecuteSingle(
		address target,
		uint256 value,
		bytes calldata callData
	) internal returns (bool success, bytes memory result) {
		assembly ("memory-safe") {
			result := mload(0x40)
			calldatacopy(result, callData.offset, callData.length)

			success := call(gas(), target, value, result, callData.length, codesize(), 0x00)

			mstore(result, returndatasize())
			returndatacopy(add(result, 0x20), 0x00, returndatasize())
			mstore(0x40, add(add(result, 0x20), returndatasize()))
		}

		if (!success) emit TryExecuteUnsuccessful(callData, result);
	}

	function executeBatch(bytes32[] calldata pointers) internal returns (bytes[] memory results) {
		// prettier-ignore
		assembly ("memory-safe") {
			results := mload(0x40)
			mstore(results, pointers.length)

			let r := add(0x20, results)
			let m := add(r, shl(0x05, pointers.length))
			calldatacopy(r, pointers.offset, shl(0x05, pointers.length))

			for { let end := m } iszero(eq(r, end)) { r := add(r, 0x20) } {
                let e := add(pointers.offset, mload(r))
                let o := add(e, calldataload(add(e, 0x40)))
                calldatacopy(m, add(o, 0x20), calldataload(o))

				if iszero(
					call(gas(), calldataload(e), calldataload(add(e, 0x20)), m, calldataload(o), codesize(), 0x00)
				) {
					returndatacopy(m, 0x00, returndatasize())
					revert(m, returndatasize())
				}

				mstore(r, m)
				mstore(m, returndatasize())

				returndatacopy(add(m, 0x20), 0x00, returndatasize())
				m := add(add(m, 0x20), returndatasize())
			}

			mstore(0x40, m)
		}
	}

	function tryExecuteBatch(bytes32[] calldata pointers) internal returns (bytes[] memory result) {
		uint256 length = pointers.length;
		result = new bytes[](length);

		for (uint256 i; i < length; ) {
			(address target, uint256 value, bytes calldata callData) = getExecution(pointers, i);
			(, result[i]) = tryExecuteSingle(target, value, callData);

			unchecked {
				i = i + 1;
			}
		}
	}

	function executeDelegate(address target, bytes calldata callData) internal returns (bytes memory result) {
		assembly ("memory-safe") {
			result := mload(0x40)
			calldatacopy(result, callData.offset, callData.length)

			if iszero(delegatecall(gas(), target, result, callData.length, codesize(), 0x00)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0xacfdb444) // ExecutionFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(result, 0x00, returndatasize())
				revert(result, returndatasize())
			}

			mstore(result, returndatasize())
			returndatacopy(add(result, 0x20), 0x00, returndatasize())
			mstore(0x40, add(add(result, 0x20), returndatasize()))
		}
	}

	function tryExecuteDelegate(
		address target,
		bytes calldata callData
	) internal returns (bool success, bytes memory result) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			calldatacopy(ptr, callData.offset, callData.length)

			success := delegatecall(gas(), target, ptr, callData.length, codesize(), 0x00)

			mstore(0x40, add(add(result, 0x20), returndatasize()))
			mstore(result, returndatasize())
			returndatacopy(add(result, 0x20), 0x00, returndatasize())
		}

		if (!success) emit TryDelegateCallUnsuccessful(callData, result);
	}

	function decodeSingle(
		bytes calldata executionData
	) internal pure returns (address target, uint256 value, bytes calldata callData) {
		assembly ("memory-safe") {
			if iszero(gt(executionData.length, 0x33)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			target := shr(0x60, calldataload(executionData.offset))
			value := calldataload(add(executionData.offset, 0x14))
			callData.offset := add(executionData.offset, 0x34)
			callData.length := sub(executionData.length, 0x34)
		}
	}

	function decodeDelegate(
		bytes calldata executionData
	) internal pure returns (address target, bytes calldata callData) {
		assembly ("memory-safe") {
			if iszero(gt(executionData.length, 0x13)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			target := shr(0x60, calldataload(executionData.offset))
			callData.offset := add(executionData.offset, 0x14)
			callData.length := sub(executionData.length, 0x14)
		}
	}

	function decodeBatch(bytes calldata executionData) internal pure returns (bytes32[] calldata pointers) {
		// prettier-ignore
		assembly ("memory-safe") {
            let u := calldataload(executionData.offset)
            let s := add(executionData.offset, u)
            let e := sub(add(executionData.offset, executionData.length), 0x20)

			pointers.offset := add(s, 0x20)
            pointers.length := calldataload(s)

            if or(shr(0x40, u), gt(add(s, shl(0x05, pointers.length)), e)) {
                mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
                revert(0x1c, 0x04)
            }

            if pointers.length {
                for { let i := pointers.length } 0x01 { } {
                    i := sub(i, 0x01)
                    let p := calldataload(add(pointers.offset, shl(0x05, i)))
                    let c := add(pointers.offset, p)
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

	function getExecution(
		bytes32[] calldata pointers,
		uint256 index
	) internal pure returns (address target, uint256 value, bytes calldata callData) {
		assembly ("memory-safe") {
			let c := add(pointers.offset, calldataload(add(pointers.offset, shl(0x05, index))))
			target := calldataload(c)
			value := calldataload(add(c, 0x20))

			let o := add(c, calldataload(add(c, 0x40)))
			callData.offset := add(o, 0x20)
			callData.length := calldataload(o)
		}
	}
}
