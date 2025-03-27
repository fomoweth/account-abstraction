// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATE, EXECTYPE_DEFAULT} from "src/types/Constants.sol";
import {ExecutionMode, CallType, ExecType, ModuleType, ValidationData} from "src/types/Types.sol";
import {EIP712} from "src/utils/EIP712.sol";
import {UUPSUpgradeable} from "src/utils/UUPSUpgradeable.sol";
import {AccountBase} from "./AccountBase.sol";
import {ModuleManager} from "./ModuleManager.sol";

/// @title AccountCore

abstract contract AccountCore is AccountBase, EIP712, ModuleManager, UUPSUpgradeable {
	using CalldataDecoder for bytes;
	using ExecutionLib for address;
	using ExecutionLib for ExecType;

	/// @dev keccak256(bytes("EnableModule(uint256 moduleTypeId,address module,bytes32 initDataHash,bytes32 userOpHash)"));
	bytes32 internal constant ENABLE_MODULE_TYPEHASH =
		0xc9285f586ac4794002dd9886bc9d760a4544a5d6a18524daa92803a337338eac;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	modifier withHook() {
		if (_isEntryPointOrSelf()) {
			address[] memory hooks = _globalHooks();
			bytes[] memory contexts;

			if (hooks.length != 0) contexts = _preCheckBatch(hooks, msg.sender, msg.value, msg.data);
			_;
			if (hooks.length != 0) _postCheckBatch(contexts);
		} else {
			address hook = _getHook(msg.sender);
			bytes memory context;

			if (hook != SENTINEL) context = _preCheck(hook, msg.sender, msg.value, msg.data);
			_;
			if (hook != SENTINEL) _postCheck(hook, context);
		}
	}

	function _initializeAccount(bytes calldata data) internal virtual {
		assembly ("memory-safe") {
			if iszero(iszero(sload(ROOT_VALIDATOR_STORAGE_SLOT))) {
				mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
				revert(0x1c, 0x04)
			}
		}

		EXECTYPE_DEFAULT.executeDelegate(data);

		assembly ("memory-safe") {
			if iszero(extcodesize(sload(ROOT_VALIDATOR_STORAGE_SLOT))) {
				mstore(0x00, 0x19b991a8) // InitializationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	function _execute(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) internal virtual returns (bytes[] memory returnData) {
		(CallType callType, ExecType execType) = mode.parseTypes();

		if (callType == CALLTYPE_SINGLE) return execType.executeSingle(executionCalldata);
		if (callType == CALLTYPE_BATCH) return execType.executeBatch(executionCalldata);
		if (callType == CALLTYPE_DELEGATE) return execType.executeDelegate(executionCalldata);
	}

	function _executeUserOp(PackedUserOperation calldata userOp, bytes32) internal virtual {
		bytes4 selector = bytes(userOp.callData[4:]).decodeSelector();

		if (selector == IERC7579Account.execute.selector || selector == IERC7579Account.executeFromExecutor.selector) {
			(ExecutionMode mode, bytes calldata executionCalldata) = bytes(userOp.callData[8:])
				.decodeExecutionModeAndCalldata();
			_execute(mode, executionCalldata);
		} else {
			address(this).callDelegate(userOp.callData[4:]);
		}
	}

	function _validateUserOp(
		address validator,
		PackedUserOperation memory userOp,
		bytes32 userOpHash
	) internal virtual onlyValidator(validator) returns (ValidationData validationData) {
		// 0x97003203: validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes),bytes32)
		bytes memory callData = abi.encodeWithSelector(0x97003203, userOp, userOpHash);

		assembly ("memory-safe") {
			if iszero(call(gas(), validator, 0x00, add(callData, 0x20), mload(callData), 0x00, 0x20)) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			validationData := mload(0x00)
		}
	}

	function _validateSignature(
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

	function _validateEnableSignature(
		address validator,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual onlyValidator(validator) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, caller())))
			mstore(add(ptr, 0x24), hash)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), signature.length)
			calldatacopy(add(ptr, 0x84), signature.offset, signature.length)

			let success := staticcall(gas(), validator, ptr, add(signature.length, 0x84), 0x00, 0x20)

			if xor(or(mload(0x00), sub(0x00, iszero(success))), ERC1271_SUCCESS) {
				mstore(0x00, 0xc48cf8ee) // EnableNotApproved()
				revert(0x1c, 0x04)
			}
		}
	}

	function _enableModule(
		bytes32 userOpHash,
		bytes calldata data
	) internal virtual returns (bytes calldata userOpSignature) {
		ModuleType moduleTypeId;
		address module;
		bytes calldata signature;
		(moduleTypeId, module, data, signature, userOpSignature) = data.decodeEnableModuleParams();

		bytes32 structHash = _enableModuleHash(moduleTypeId, module, data, userOpHash);
		(address validator, bytes calldata innerSignature) = _decodeSignature(signature);

		_validateEnableSignature(validator, _hashTypedData(structHash), innerSignature);
		_installModule(moduleTypeId, module, data);
	}

	function _decodeSignature(
		bytes calldata signature
	) internal view virtual returns (address validator, bytes calldata innerSignature) {
		assembly ("memory-safe") {
			switch signature.length
			case 0x00 {
				validator := sload(ROOT_VALIDATOR_STORAGE_SLOT)
				innerSignature.offset := 0x00
				innerSignature.length := 0x00
			}
			default {
				if lt(signature.length, 0x14) {
					mstore(0x00, 0x8baa579f) // InvalidSignature()
					revert(0x1c, 0x04)
				}

				validator := shr(0x60, calldataload(signature.offset))
				innerSignature.offset := add(signature.offset, 0x14)
				innerSignature.length := sub(signature.length, 0x14)
			}
		}
	}

	function _decodeUserOpNonce(
		PackedUserOperation calldata userOp
	) internal pure virtual returns (address validator, bool isEnableMode) {
		assembly ("memory-safe") {
			let nonce := calldataload(add(userOp, 0x20))
			validator := shr(0x60, shl(0x20, nonce))
			isEnableMode := eq(shl(0xf8, shr(0xf8, nonce)), shl(0xf8, 0x01))
		}
	}

	function _enableModuleHash(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data,
		bytes32 userOpHash
	) internal pure virtual returns (bytes32 hash) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(ptr, ENABLE_MODULE_TYPEHASH)
			mstore(add(ptr, 0x20), moduleTypeId)
			mstore(add(ptr, 0x40), shr(0x60, shl(0x60, module)))
			calldatacopy(add(ptr, 0x60), data.offset, data.length)
			mstore(add(ptr, 0x60), keccak256(add(ptr, 0x60), data.length))
			mstore(add(ptr, 0x80), userOpHash)
			hash := keccak256(ptr, 0xa0)
		}
	}

	function _preCheck(
		address hook,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual returns (bytes memory context) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, msgSender)))
			mstore(add(ptr, 0x24), msgValue)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), msgData.length)
			calldatacopy(add(ptr, 0x84), msgData.offset, msgData.length)

			if iszero(call(gas(), hook, 0x00, ptr, add(msgData.length, 0x84), codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(add(context, 0x20), returndatasize()))
			mstore(context, returndatasize())
			returndatacopy(add(context, 0x20), 0x00, returndatasize())
		}
	}

	function _postCheck(address hook, bytes memory context) internal virtual {
		assembly ("memory-safe") {
			let offset := add(context, 0x20)
			let length := mload(context)
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

			if iszero(call(gas(), hook, 0x00, ptr, add(length, 0x44), codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _preCheckBatch(
		address[] memory hooks,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual returns (bytes[] memory contexts) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, add(msgData.length, 0x84)))

			mstore(ptr, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, msgSender)))
			mstore(add(ptr, 0x24), msgValue)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), msgData.length)
			calldatacopy(add(ptr, 0x84), msgData.offset, msgData.length)

			contexts := mload(0x40)

			let length := mload(hooks)
			let offset := add(add(contexts, 0x20), shl(0x05, length))

			mstore(contexts, length)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				let hook := shr(0x60, shl(0x60, mload(add(add(hooks, 0x20), shl(0x05, i)))))

				if iszero(call(gas(), hook, 0x00, ptr, add(msgData.length, 0x84), codesize(), 0x00)) {
					mstore(0x00, 0x4a3a865b) // PreCheckFailed(address)
					mstore(0x20, hook)
					revert(0x1c, 0x24)
				}

				mstore(add(add(contexts, 0x20), shl(0x05, i)), offset)
				mstore(offset, add(returndatasize(), 0x60))
				mstore(add(offset, 0x20), hook)
				mstore(add(offset, 0x40), 0x40)
				mstore(add(offset, 0x60), returndatasize())
				returndatacopy(add(offset, 0x80), 0x00, returndatasize())
				offset := add(add(offset, 0x80), returndatasize())
			}

			mstore(0x40, offset)
		}
	}

	function _postCheckBatch(bytes[] memory contexts) internal virtual {
		assembly ("memory-safe") {
			let length := mload(contexts)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				let offset := mload(add(add(contexts, 0x20), shl(0x05, i)))
				let hook := shr(0x60, shl(0x60, mload(add(offset, 0x20))))
				let contextLength := mload(add(offset, 0x60))
				let contextOffset := add(offset, 0x80)

				let ptr := mload(0x40)

				mstore(ptr, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)

				let pos := add(ptr, 0x04)
				let guard := add(pos, contextLength)

				for { } 0x01 { } {
					mstore(pos, mload(contextOffset))
					pos := add(pos, 0x20)
					if eq(pos, guard) { break }
					contextOffset := add(contextOffset, 0x20)
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), hook, 0x00, ptr, add(contextLength, 0x04), codesize(), 0x00)) {
					mstore(0x00, 0xa154e16d) // PostCheckFailed(address)
					mstore(0x20, hook)
					revert(0x1c, 0x24)
				}
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

			if iszero(configuration) {
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

			let callType := shr(0xf8, configuration)
			let module := shr(0x60, shl(0x60, configuration))

			mstore(0x00, module)
			mstore(0x20, MODULES_STORAGE_SLOT)

			configuration := sload(keccak256(0x00, 0x40))

			// MODULE_TYPE_FALLBACK: 0x03
			if xor(shr(0xf8, configuration), 0x03) {
				mstore(0x00, 0x2125deae) // InvalidModuleType()
				revert(0x1c, 0x04)
			}

			let hook := shr(0x60, shl(0x60, configuration))
			let context

			if iszero(hook) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, module)
				revert(0x1c, 0x24)
			}

			if and(xor(hook, SENTINEL), xor(callType, 0xFE)) {
				context := allocate(add(calldatasize(), 0x84))

				mstore(context, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
				mstore(add(context, 0x04), shr(0x60, shl(0x60, caller())))
				mstore(add(context, 0x24), callvalue())
				mstore(add(context, 0x44), 0x60)
				mstore(add(context, 0x64), calldatasize())
				calldatacopy(add(context, 0x84), 0x00, calldatasize())

				if iszero(call(gas(), hook, 0x00, context, add(calldatasize(), 0x84), codesize(), 0x00)) {
					mstore(0x00, 0x4a3a865b) // PreCheckFailed(address)
					mstore(0x20, hook)
					revert(0x1c, 0x24)
				}

				context := allocate(add(returndatasize(), 0x20))
				mstore(context, returndatasize())
				returndatacopy(add(context, 0x20), 0x00, returndatasize())
			}

			let callData := allocate(calldatasize())
			calldatacopy(callData, 0x00, calldatasize())
			mstore(allocate(0x14), shl(0x60, caller()))

			let success
			switch callType
			// CALLTYPE_SINGLE
			case 0x00 {
				success := call(gas(), module, callvalue(), callData, add(calldatasize(), 0x14), codesize(), 0x00)
			}
			// CALLTYPE_STATIC
			case 0xFE {
				success := staticcall(gas(), module, callData, add(calldatasize(), 0x14), codesize(), 0x00)
			}
			// CALLTYPE_DELEGATE
			case 0xFF {
				success := delegatecall(gas(), module, callData, add(calldatasize(), 0x14), codesize(), 0x00)
			}
			default {
				mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
				mstore(0x20, shl(0xf8, callType))
				revert(0x1c, 0x24)
			}

			if iszero(success) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			let returnData := allocate(add(returndatasize(), 0x20))
			mstore(returnData, returndatasize())
			returndatacopy(add(returnData, 0x20), 0x00, returndatasize())

			if and(xor(hook, SENTINEL), xor(callType, 0xFE)) {
				let length := mload(context)
				let offset := add(context, 0x20)
				context := allocate(add(length, 0x44))

				mstore(context, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)
				mstore(add(context, 0x04), 0x20)
				mstore(add(context, 0x24), length)

				let pos := add(context, 0x44)
				let guard := add(pos, length)

				// prettier-ignore
				for { } 0x01 { } {
					mstore(pos, mload(offset))
					pos := add(pos, 0x20)
					if eq(pos, guard) { break }
					offset := add(offset, 0x20)
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), hook, 0x00, context, add(length, 0x44), codesize(), 0x00)) {
					mstore(0x00, 0xa154e16d) // PostCheckFailed(address)
					mstore(0x20, hook)
					revert(0x1c, 0x24)
				}
			}

			return(add(returnData, 0x20), add(mload(returnData), 0x20))
		}
	}
}
