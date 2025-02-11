// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint, PackedUserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IValidator} from "src/interfaces/modules/IERC7579Modules.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATE, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR} from "src/types/Constants.sol";
import {ExecutionMode, CallType, ExecType} from "src/types/Types.sol";
import {AccountModule} from "./AccountModule.sol";

/// @title Account

abstract contract Account is AccountModule {
	using BytesLib for bytes;
	using ExecutionLib for bytes;

	modifier onlyEntryPoint() {
		_checkEntryPoint();
		_;
	}

	modifier onlyEntryPointOrSelf() {
		_checkEntryPointOrSelf();
		_;
	}

	modifier onlyExecutor() {
		_checkModule(msg.sender, MODULE_TYPE_EXECUTOR);
		_;
	}

	modifier onlyValidator(address validator) {
		_checkModule(validator, MODULE_TYPE_VALIDATOR);
		_;
	}

	modifier payPrefund(uint256 missingAccountFunds) {
		_;
		_payPrefund(missingAccountFunds);
	}

	modifier withHook() {
		address hook = _hook(msg.sender);
		if (hook == SENTINEL) {
			_;
		} else {
			bytes memory hookData = _preCheck(hook, msg.sender, msg.value, msg.data);
			_;
			_postCheck(hook, hookData);
		}
	}

	function entryPoint() external pure virtual returns (IEntryPoint) {
		return IEntryPoint(ENTRYPOINT);
	}

	function addDeposit() external payable virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb760faf900000000000000000000000000000000000000000000000000000000) // depositTo(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))

			if iszero(call(gas(), ENTRYPOINT, callvalue(), ptr, 0x24, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	function withdrawTo(address recipient, uint256 amount) external payable virtual onlyEntryPointOrSelf {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x205c287800000000000000000000000000000000000000000000000000000000) // withdrawTo(address,uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), ENTRYPOINT, 0x00, ptr, 0x44, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getDeposit() external view virtual returns (uint256 deposit) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000) // balanceOf(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))

			// prettier-ignore
			deposit := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x24, 0x00,0x20)))
		}
	}

	function getNonce() external view virtual returns (uint256 nonce) {
		return getNonce(0);
	}

	function getNonce(uint192 key) public view virtual returns (uint256 nonce) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x35567e1a00000000000000000000000000000000000000000000000000000000) // getNonce(address,uint192)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))
			mstore(add(ptr, 0x24), shr(0x40, shl(0x40, key)))

			// prettier-ignore
			nonce := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x44, 0x00, 0x20)))
		}
	}

	function _execute(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) internal virtual returns (bytes[] memory results) {
		(CallType callType, ExecType execType) = mode.parseTypes();

		if (callType == CALLTYPE_SINGLE) return executionCalldata.executeSingle(execType);
		if (callType == CALLTYPE_BATCH) return executionCalldata.executeBatch(execType);
		if (callType == CALLTYPE_DELEGATE) return executionCalldata.executeDelegate(execType);
	}

	function _execute(
		CallType callType,
		address target,
		uint256 value,
		bytes calldata callData
	) internal virtual returns (bytes memory returnData) {
		assembly ("memory-safe") {
			let success
			let ptr := mload(0x40)
			calldatacopy(ptr, callData.offset, callData.length)

			switch shl(0xf8, callType)
			// CALLTYPE_SINGLE
			case 0x00 {
				success := call(gas(), target, value, ptr, callData.length, codesize(), 0x00)
			}
			// CALLTYPE_DELEGATE
			case 0xFF {
				success := delegatecall(gas(), target, ptr, callData.length, codesize(), 0x00)
			}
			default {
				mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
				mstore(0x20, callType)
				revert(0x1c, 0x24)
			}

			returnData := mload(0x40)

			if iszero(success) {
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
	}

	function _validateUserOp(
		address validator,
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) internal virtual onlyValidator(validator) returns (uint256 validationData) {
		return IValidator(validator).validateUserOp(userOp, userOpHash);
	}

	function _isValidSignature(
		address validator,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual onlyValidator(validator) returns (bytes4 magicValue) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, caller())))
			mstore(add(ptr, 0x24), hash)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), signature.length)
			calldatacopy(add(ptr, 0x84), signature.offset, signature.length)

			let success := staticcall(gas(), validator, ptr, add(signature.length, 0x84), 0x00, 0x20)

			switch and(iszero(signature.length), eq(hash, mul(div(not(signature.length), 0xffff), 0x7739)))
			case 0x01 {
				magicValue := or(mload(0x00), sub(0x00, iszero(and(eq(shr(0xf0, mload(0x00)), 0x7739), success))))
			}
			default {
				magicValue := or(mload(0x00), sub(0x00, iszero(success)))
			}
		}
	}

	function _decodeSignature(
		bytes calldata signature
	) internal view virtual returns (address validator, bytes calldata innerSignature) {
		(validator, innerSignature) = signature.length != 0
			? (signature.toAddress(), signature[20:])
			: (_rootValidator(), signature);
	}

	function _parseValidator(uint256 nonce) internal pure virtual returns (address validator) {
		assembly ("memory-safe") {
			validator := shr(0x60, nonce)
		}
	}

	function _preCheck(
		address hook,
		address msgSender,
		uint256 msgValue,
		bytes memory msgData
	) internal virtual returns (bytes memory hookData) {
		assembly ("memory-safe") {
			let offset := add(msgData, 0x20)
			let length := mload(msgData)

			let ptr := mload(0x40)

			mstore(ptr, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, msgSender)))
			mstore(add(ptr, 0x24), msgValue)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), length)

			let pos := add(ptr, 0x84)
			let guard := add(pos, length)

			// prettier-ignore
			for { } 0x01 { } {
				mstore(pos, mload(offset))
				pos := add(pos, 0x20)
				if eq(pos, guard) { break }
				offset := add(offset, 0x20)
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(call(gas(), hook, 0x00, ptr, add(length, 0x84), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(hookData, add(returndatasize(), 0x20)))
			mstore(hookData, returndatasize())
			returndatacopy(add(hookData, 0x20), 0x00, returndatasize())
		}
	}

	function _postCheck(address hook, bytes memory hookData) internal virtual {
		assembly ("memory-safe") {
			let offset := add(hookData, 0x20)
			let length := mload(hookData)

			let ptr := mload(0x40)

			mstore(ptr, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), length)

			let pos := add(ptr, 0x44)
			let guard := add(pos, length)

			// prettier-ignore
			for { } 0x01 { } {
				mstore(pos, mload(offset))
				pos := add(pos, 0x20)
				if eq(pos, guard) { break }
				offset := add(offset, 0x20)
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(call(gas(), hook, 0x00, ptr, add(length, 0x44), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _payPrefund(uint256 missingAccountFunds) internal virtual {
		assembly ("memory-safe") {
			if missingAccountFunds {
				pop(call(gas(), caller(), missingAccountFunds, codesize(), 0x00, codesize(), 0x00))
			}
		}
	}

	function _checkEntryPoint() internal view virtual {
		assembly ("memory-safe") {
			if xor(caller(), ENTRYPOINT) {
				mstore(0x00, 0x8e4a23d6) // Unauthorized(address)
				mstore(0x20, shr(0x60, shl(0x60, caller())))
				revert(0x1c, 0x24)
			}
		}
	}

	function _checkEntryPointOrSelf() internal view virtual {
		assembly ("memory-safe") {
			if and(xor(caller(), ENTRYPOINT), xor(caller(), address())) {
				mstore(0x00, 0x8e4a23d6) // Unauthorized(address)
				mstore(0x20, shr(0x60, shl(0x60, caller())))
				revert(0x1c, 0x24)
			}
		}
	}

	function _fallback() internal virtual {
		assembly ("memory-safe") {
			function allocate(length) -> ptr {
				ptr := mload(0x40)
				mstore(0x40, add(ptr, length))
			}

			let selector := shr(0xe0, calldataload(0x00))

			mstore(0x00, shl(0xe0, selector))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))
			let callType := shl(0xf8, shr(0xf8, configuration))
			let handler := shr(0x60, shl(0x60, configuration))

			if iszero(handler) {
				// 0x150b7a02: onERC721Received(address,address,uint256,bytes)
				// 0xf23a6e61: onERC1155Received(address,address,uint256,uint256,bytes)
				// 0xbc197c81: onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
				if or(eq(selector, 0x150b7a02), or(eq(selector, 0xf23a6e61), eq(selector, 0xbc197c81))) {
					mstore(0x20, selector)
					return(0x3c, 0x20)
				}

				mstore(0x00, 0xc2a825f5) // UnknownSelector(bytes4)
				mstore(0x20, shl(0xe0, selector))
				revert(0x1c, 0x24)
			}

			mstore(0x00, handler)
			mstore(0x20, MODULES_STORAGE_SLOT)

			configuration := sload(keccak256(0x00, 0x40))

			let moduleTypeId := shr(0xf8, configuration)
			let hook := shr(0x60, shl(0x60, configuration))
			let hookData

			if or(iszero(hook), xor(moduleTypeId, 0x03)) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, handler)
				revert(0x1c, 0x24)
			}

			if xor(hook, SENTINEL) {
				hookData := allocate(add(calldatasize(), 0x84))

				mstore(hookData, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
				mstore(add(hookData, 0x04), shr(0x60, shl(0x60, caller())))
				mstore(add(hookData, 0x24), callvalue())
				mstore(add(hookData, 0x44), 0x60)
				mstore(add(hookData, 0x64), calldatasize())
				calldatacopy(add(hookData, 0x84), 0x00, calldatasize())

				if iszero(call(gas(), hook, 0x00, hookData, add(calldatasize(), 0x84), 0x00, 0x00)) {
					returndatacopy(hookData, 0x00, returndatasize())
					revert(hookData, returndatasize())
				}

				hookData := allocate(returndatasize())
				mstore(hookData, returndatasize())
				returndatacopy(add(hookData, 0x20), 0x00, returndatasize())
			}

			let ptr := allocate(calldatasize())
			calldatacopy(ptr, 0x00, calldatasize())

			let success

			switch shr(0xf8, callType)
			// CALLTYPE_SINGLE
			case 0x00 {
				mstore(allocate(0x14), shl(0x60, caller()))
				success := call(gas(), handler, 0x00, ptr, add(calldatasize(), 0x14), 0x00, 0x00)
			}
			// CALLTYPE_STATIC
			case 0xFE {
				mstore(allocate(0x14), shl(0x60, caller()))
				success := staticcall(gas(), handler, ptr, add(calldatasize(), 0x14), 0x00, 0x00)
			}
			// CALLTYPE_DELEGATE
			case 0xFF {
				success := delegatecall(gas(), handler, ptr, calldatasize(), 0x00, 0x00)
			}
			default {
				mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
				mstore(0x20, callType)
				revert(0x1c, 0x24)
			}

			if iszero(success) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			let returndataSize := returndatasize()
			let returndata := allocate(returndataSize)

			mstore(returndata, returndataSize)
			returndatacopy(add(returndata, 0x20), 0x00, returndataSize)

			if xor(hook, SENTINEL) {
				let offset := add(hookData, 0x20)
				let length := mload(hookData)

				ptr := allocate(add(length, 0x44))

				mstore(ptr, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)
				mstore(add(ptr, 0x04), 0x20)
				mstore(add(ptr, 0x24), length)

				let pos := add(ptr, 0x44)
				let guard := add(pos, length)

				// prettier-ignore
				for { } 0x01 { } {
					mstore(pos, mload(offset))
					pos := add(pos, 0x20)
					if eq(pos, guard) { break }
					offset := add(offset, 0x20)
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), hook, 0x00, ptr, add(length, 0x44), 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			return(add(returndata, 0x20), returndataSize)
		}
	}
}
