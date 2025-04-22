// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Calldata} from "src/libraries/Calldata.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {ExecutionMode, CallType, ExecType, ModuleType, ValidationData, ValidationMode} from "src/types/DataTypes.sol";
import {ModuleManager} from "./ModuleManager.sol";

/// @title AccountCore
/// @notice Implements ERC-4337 and ERC-7579 standards for account management and access control
abstract contract AccountCore is IVortex, EIP712, ModuleManager, UUPSUpgradeable {
	using CalldataDecoder for bytes;
	using EnumerableSetLib for EnumerableSetLib.AddressSet;
	using ExecutionLib for ExecType;

	error InvalidInitialization();

	error InitializationFailed();

	error InvalidParametersLength();

	error InvalidSignature();

	error InvalidValidator();

	error InvalidValidationMode(ValidationMode mode);

	error EnableNotApproved();

	/// @dev keccak256(bytes("EnableModule(uint256 moduleTypeId,address module,bytes32 initDataHash,bytes32 userOpHash)"));
	bytes32 private constant ENABLE_MODULE_TYPEHASH =
		0xc9285f586ac4794002dd9886bc9d760a4544a5d6a18524daa92803a337338eac;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	ValidationMode internal constant VALIDATION_MODE_DEFAULT = ValidationMode.wrap(0x00);
	ValidationMode internal constant VALIDATION_MODE_ENABLE = ValidationMode.wrap(0x01);

	/// @notice Verifies that the caller is an executor module currently installed on the account
	modifier onlyExecutor() virtual {
		require(
			_isModuleInstalled(MODULE_TYPE_EXECUTOR, msg.sender, Calldata.emptyBytes()),
			ModuleNotInstalled(MODULE_TYPE_EXECUTOR, msg.sender)
		);
		_;
	}

	/// @notice Verifies that the specified validator module is currently installed on the account
	modifier onlyValidator(address validator) virtual {
		require(
			_isModuleInstalled(MODULE_TYPE_VALIDATOR, validator, Calldata.emptyBytes()),
			ModuleNotInstalled(MODULE_TYPE_VALIDATOR, validator)
		);
		_;
	}

	/// @notice Handles pre and post execution checks for global or module-specific hooks installed on the account
	/// @dev 	If called by EntryPoint or the account itself, invokes batch checks on all global hooks.
	///      	Otherwise, performs hook checks specific to the calling module, if one is installed.
	modifier withHook() virtual {
		if (_isEntryPointOrSelf()) {
			address[] memory hooks = _getHooks();
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
		AccountStorage storage state = _getAccountStorage();
		if (state.rootValidator != address(0)) revert InvalidInitialization();

		assembly ("memory-safe") {
			if lt(data.length, 0x2c) {
				mstore(0x00, 0x0fe4a1df) // InvalidParametersLength()
				revert(0x1c, 0x04)
			}

			let bootstrap := shr(0x60, calldataload(data.offset))
			data.offset := add(data.offset, 0x14)
			data.length := sub(data.length, 0x14)

			let ptr := mload(0x40)
			mstore(0x40, add(ptr, data.length))
			calldatacopy(ptr, data.offset, data.length)

			if iszero(delegatecall(gas(), bootstrap, ptr, data.length, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		if (state.rootValidator == address(0) || !_isInitialized(state.rootValidator)) revert InitializationFailed();
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

	function _validateUserOp(
		address validator,
		PackedUserOperation memory userOp,
		bytes32 userOpHash
	) internal virtual onlyValidator(validator) returns (ValidationData validationData) {
		assembly ("memory-safe") {
			function storeOffset(ptr, slot, offset) -> pos {
				mstore(ptr, offset)
				let length := and(add(mload(mload(slot)), 0x1f), not(0x1f))
				pos := add(offset, add(length, 0x20))
			}

			function storeBytes(ptr, slot) -> pos {
				let offset := mload(slot)
				let length := mload(offset)
				mstore(ptr, length)

				offset := add(offset, 0x20)
				let guard := add(offset, length)

				// prettier-ignore
				for { pos := add(ptr, 0x20) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
					mstore(pos, mload(offset))
				}
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x9700320300000000000000000000000000000000000000000000000000000000) // validateUserOp(PackedUserOperation,bytes32)
			mstore(add(ptr, 0x04), 0x40)
			mstore(add(ptr, 0x24), userOpHash)
			mstore(add(ptr, 0x44), shr(0x60, shl(0x60, mload(userOp)))) // sender
			mstore(add(ptr, 0x64), mload(add(userOp, 0x20))) // nonce

			let pos := 0x120
			pos := storeOffset(add(ptr, 0x84), add(userOp, 0x40), pos) // initCode
			pos := storeOffset(add(ptr, 0xa4), add(userOp, 0x60), pos) // callData

			mstore(add(ptr, 0xc4), mload(add(userOp, 0x80))) // accountGasLimits
			mstore(add(ptr, 0xe4), mload(add(userOp, 0xa0))) // preVerificationGas
			mstore(add(ptr, 0x104), mload(add(userOp, 0xc0))) // gasFees

			pos := storeOffset(add(ptr, 0x124), add(userOp, 0xe0), pos) // paymasterAndData
			pos := storeOffset(add(ptr, 0x144), add(userOp, 0x100), pos) // signature

			pos := add(ptr, 0x164)
			pos := storeBytes(pos, add(userOp, 0x40)) // initCode
			pos := storeBytes(pos, add(userOp, 0x60)) // callData
			pos := storeBytes(pos, add(userOp, 0xe0)) // paymasterAndData
			pos := storeBytes(pos, add(userOp, 0x100)) // signature

			if iszero(call(gas(), validator, 0x00, ptr, sub(pos, ptr), 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			validationData := mload(0x00)
		}
	}

	function _enableModule(
		bytes calldata data,
		bytes32 userOpHash
	) internal virtual returns (bytes calldata userOpSignature) {
		ModuleType moduleTypeId;
		address module;
		bytes calldata signature;
		(moduleTypeId, module, data, signature, userOpSignature) = data.decodeEnableModuleParams();

		(address validator, bytes calldata innerSignature) = _decodeSignature(signature);
		bytes32 structHash = _enableModuleHash(moduleTypeId, module, data, userOpHash);

		_validateEnableSignature(validator, _hashTypedData(structHash), innerSignature);
		_installModule(moduleTypeId, module, data);
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

			context := mload(0x40)
			mstore(context, returndatasize())
			mstore(0x40, add(add(context, 0x20), returndatasize()))
			returndatacopy(add(context, 0x20), 0x00, returndatasize())
		}
	}

	function _postCheck(address hook, bytes memory context) internal virtual {
		assembly ("memory-safe") {
			let offset := add(context, 0x20)
			let length := mload(context)
			let guard := add(offset, length)

			let ptr := mload(0x40)

			mstore(ptr, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), length)

			// prettier-ignore
			for { let pos := add(ptr, 0x44) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
				mstore(pos, mload(offset))
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
			let ptrSize := add(msgData.length, 0x84)
			mstore(0x40, add(ptr, ptrSize))

			mstore(ptr, 0xd68f602500000000000000000000000000000000000000000000000000000000) // preCheck(address,uint256,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, msgSender)))
			mstore(add(ptr, 0x24), msgValue)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), msgData.length)
			calldatacopy(add(ptr, 0x84), msgData.offset, msgData.length)

			contexts := mload(0x40)
			let length := mload(hooks)
			mstore(contexts, length)

			let offset := add(add(contexts, 0x20), shl(0x05, length))

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				let hook := shr(0x60, shl(0x60, mload(add(add(hooks, 0x20), shl(0x05, i)))))

				if iszero(call(gas(), hook, 0x00, ptr, ptrSize, codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
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
			let ptr := mload(0x40)

			mstore(ptr, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)

			// prettier-ignore
			for { let i } lt(i, mload(contexts)) { i := add(i, 0x01) } {
				let offset := mload(add(add(contexts, 0x20), shl(0x05, i)))
				let hook := shr(0x60, shl(0x60, mload(add(offset, 0x20))))
				let contextLength := mload(add(offset, 0x60))
				let contextOffset := add(offset, 0x80)
				let guard := add(contextOffset, contextLength)

				for { let pos := add(ptr, 0x04) } lt(contextOffset, guard) { pos := add(pos, 0x20) contextOffset := add(contextOffset, 0x20) } {
					mstore(pos, mload(contextOffset))
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), hook, 0x00, ptr, add(contextLength, 0x04), codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function _preValidateERC4337(
		bytes32 userOpHash,
		PackedUserOperation memory userOp,
		uint256 missingAccountFunds
	) internal virtual returns (bytes32 hookHash, bytes memory hookSignature) {
		address preValidationHook = _getPreValidationHook(MODULE_TYPE_PREVALIDATION_HOOK_ERC4337);
		if (preValidationHook == address(0)) return (userOpHash, userOp.signature);

		assembly ("memory-safe") {
			function storeOffset(ptr, slot, offset) -> pos {
				mstore(ptr, offset)
				let length := and(add(mload(mload(slot)), 0x1f), not(0x1f))
				pos := add(offset, add(length, 0x20))
			}

			function storeBytes(ptr, slot) -> pos {
				let offset := mload(slot)
				let length := mload(offset)
				mstore(ptr, length)

				offset := add(offset, 0x20)
				let guard := add(offset, length)

				// prettier-ignore
				for { pos := add(ptr, 0x20) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
					mstore(pos, mload(offset))
				}
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xe24f8f9300000000000000000000000000000000000000000000000000000000) // preValidationHookERC4337(PackedUserOperation,uint256,bytes32)
			mstore(add(ptr, 0x04), 0x60)
			mstore(add(ptr, 0x24), missingAccountFunds)
			mstore(add(ptr, 0x44), userOpHash)
			mstore(add(ptr, 0x64), shr(0x60, shl(0x60, mload(userOp)))) // sender
			mstore(add(ptr, 0x84), mload(add(userOp, 0x20))) // nonce

			let pos := 0x120
			pos := storeOffset(add(ptr, 0xa4), add(userOp, 0x40), pos) // initCode
			pos := storeOffset(add(ptr, 0xc4), add(userOp, 0x60), pos) // callData

			mstore(add(ptr, 0xe4), mload(add(userOp, 0x80))) // accountGasLimits
			mstore(add(ptr, 0x104), mload(add(userOp, 0xa0))) // preVerificationGas
			mstore(add(ptr, 0x124), mload(add(userOp, 0xc0))) // gasFees

			pos := storeOffset(add(ptr, 0x144), add(userOp, 0xe0), pos) // paymasterAndData
			pos := storeOffset(add(ptr, 0x164), add(userOp, 0x100), pos) // signature

			pos := add(ptr, 0x184)
			pos := storeBytes(pos, add(userOp, 0x40)) // initCode
			pos := storeBytes(pos, add(userOp, 0x60)) // callData
			pos := storeBytes(pos, add(userOp, 0xe0)) // paymasterAndData
			pos := storeBytes(pos, add(userOp, 0x100)) // signature

			if iszero(call(gas(), preValidationHook, 0x00, ptr, sub(pos, ptr), codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			returndatacopy(ptr, 0x00, 0x60)

			hookHash := mload(ptr)
			let hookSignatureLength := mload(add(ptr, 0x40))
			hookSignature := mload(0x40)

			mstore(0x40, add(add(hookSignature, 0x20), hookSignatureLength))
			mstore(hookSignature, hookSignatureLength)
			returndatacopy(add(hookSignature, 0x20), 0x60, hookSignatureLength)
		}
	}

	function _preValidateERC1271(
		bytes32 hash,
		bytes memory signature
	) internal view virtual returns (bytes32 hookHash, bytes memory hookSignature) {
		address preValidationHook = _getPreValidationHook(MODULE_TYPE_PREVALIDATION_HOOK_ERC1271);
		if (preValidationHook == address(0)) return (hash, signature);

		assembly ("memory-safe") {
			let offset := add(signature, 0x20)
			let length := mload(signature)
			let guard := add(offset, length)

			let ptr := mload(0x40)

			mstore(ptr, 0x7a0468b700000000000000000000000000000000000000000000000000000000) // preValidationHookERC1271(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, caller())))
			mstore(add(ptr, 0x24), hash)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), length)

			// prettier-ignore
			for { let pos := add(ptr, 0x84) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
				mstore(pos, mload(offset))
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(staticcall(gas(), preValidationHook, ptr, add(length, 0x84), codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			returndatacopy(ptr, 0x00, 0x60)

			hookHash := mload(ptr)
			length := mload(add(ptr, 0x40))
			hookSignature := mload(0x40)

			mstore(0x40, add(add(hookSignature, 0x20), length))
			mstore(hookSignature, length)
			returndatacopy(add(hookSignature, 0x20), 0x60, length)
		}
	}

	function _validateERC7739Support(
		address[] memory validators,
		bytes32 hash
	) internal view virtual returns (bytes4 magicValue) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, 0xa4))

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, caller())))
			mstore(add(ptr, 0x24), hash)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), 0x00)
			mstore(add(ptr, 0x84), 0x00)

			let offset := add(validators, 0x20)
			let length := mload(validators)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				let validator := mload(add(offset, shl(0x05, i)))

				if staticcall(gas(), validator, ptr, 0xa4, 0x00, 0x20) {
					let support := mload(0x00)
					if eq(shr(0xf0, support), 0x7739) {
						if gt(support, magicValue) {
							magicValue := support
						}
					}
				}
			}

			if iszero(magicValue) {
				magicValue := ERC1271_FAILED
			}
		}
	}

	function _validateSignature(
		address validator,
		bytes32 hash,
		bytes memory signature
	) internal view virtual onlyValidator(validator) returns (bytes4 magicValue) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let offset := add(signature, 0x20)
			let length := mload(signature)
			let guard := add(offset, length)

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, caller())))
			mstore(add(ptr, 0x24), hash)
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), length)

			// prettier-ignore
			for { let pos := add(ptr, 0x84) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
				mstore(pos, mload(offset))
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			let success := staticcall(gas(), validator, ptr, add(length, 0x84), 0x00, 0x20)

			magicValue := or(mload(0x00), sub(0x00, iszero(success)))
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
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))
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

	function _decodeSignature(
		bytes calldata signature
	) internal view virtual returns (address validator, bytes calldata innerSignature) {
		if (signature.length == 0) return (_rootValidator(), signature);

		assembly ("memory-safe") {
			if lt(signature.length, 0x14) {
				mstore(0x00, 0x8baa579f) // InvalidSignature()
				revert(0x1c, 0x04)
			}

			validator := shr(0x60, calldataload(signature.offset))
			innerSignature.offset := add(signature.offset, 0x14)
			innerSignature.length := sub(signature.length, 0x14)
		}
	}

	function _decodeUserOpNonce(
		PackedUserOperation calldata userOp
	) internal view virtual returns (address validator, ValidationMode mode) {
		assembly ("memory-safe") {
			let nonce := calldataload(add(userOp, 0x20))
			validator := shr(0x60, shl(0x20, nonce))
			mode := shl(0xf8, shr(0xf8, nonce))

			if iszero(shl(0x60, validator)) {
				mstore(0x00, 0xcc08c89e) // InvalidValidator()
				revert(0x1c, 0x04)
			}

			if gt(mode, shl(0xf8, 0x01)) {
				mstore(0x00, 0xcc08c89e) // InvalidValidationMode(bytes1)
				mstore(0x20, mode)
				revert(0x1c, 0x24)
			}
		}
	}

	function _enableModuleHash(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data,
		bytes32 userOpHash
	) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, ENABLE_MODULE_TYPEHASH)
			mstore(add(ptr, 0x20), moduleTypeId)
			mstore(add(ptr, 0x40), module)

			calldatacopy(add(ptr, 0x60), data.offset, data.length)
			mstore(add(ptr, 0x60), keccak256(add(ptr, 0x60), data.length))
			mstore(add(ptr, 0x80), userOpHash)

			digest := keccak256(ptr, 0xa0)

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
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
			mstore(0x20, HOOKS_STORAGE_SLOT)

			let hook := shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))
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
					returndatacopy(context, 0x00, returndatasize())
					revert(context, returndatasize())
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
				let offset := add(context, 0x20)
				let length := mload(context)
				let guard := add(offset, length)

				context := allocate(add(length, 0x44))

				mstore(context, 0x173bf7da00000000000000000000000000000000000000000000000000000000) // postCheck(bytes)
				mstore(add(context, 0x04), 0x20)
				mstore(add(context, 0x24), length)

				// prettier-ignore
				for { let pos := add(context, 0x44) } lt(offset, guard) { pos := add(pos, 0x20) offset := add(offset, 0x20) } {
					mstore(pos, mload(offset))
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), hook, 0x00, context, add(length, 0x44), codesize(), 0x00)) {
					returndatacopy(context, 0x00, returndatasize())
					revert(context, returndatasize())
				}
			}

			return(add(returnData, 0x20), add(mload(returnData), 0x20))
		}
	}
}
