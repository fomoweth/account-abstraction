// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {SentinelList} from "src/types/SentinelList.sol";
import {CalldataDecoder} from "./CalldataDecoder.sol";
import {CustomRevert} from "./CustomRevert.sol";

/// @title ModuleLib
/// @notice Provides functions to handle the management of ERC-7579 modules

library ModuleLib {
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;

	error InvalidModule(address module);
	error InvalidModuleTypeId(uint256 moduleTypeId);

	error ValidatorAlreadyInstalled(address validator);
	error ValidatorNotInstalled(address validator);
	error NoValidatorInstalled();

	error ExecutorAlreadyInstalled(address executor);
	error ExecutorNotInstalled(address executor);

	error FallbackHandlerAlreadyInstalled(address handler, bytes4 selector);
	error FallbackHandlerNotInstalled(bytes4 selector);

	error HookAlreadyInstalled(address hook);
	error HookNotInstalled(address hook);

	error LengthMismatch();

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.validators")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant VALIDATORS_STORAGE_SLOT =
		0xf2c1f63b10845c1394082ccd2352280b1281c904a50557aad80ff67eca1ddb00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.executors")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant EXECUTORS_STORAGE_SLOT =
		0xf9162d146b6422df1bb2630e4e3d64a305decb164733850b4dcfd08f5c72b800;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.fallbackHandlers")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant FALLBACK_HANDLERS_STORAGE_SLOT =
		0xe9bbfc6a7c1b005e63cb26d446b1154a357dd2dded84acdf0558b07639dcb300;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.hook")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant HOOK_STORAGE_SLOT = 0xaf4f685d452ea61d76faaeadc5c73cbfc37c47e989c36c89cfc7f80215867800;

	uint256 internal constant MODULE_TYPE_MULTI = 0;
	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;

	uint256 internal constant SELECTORS_INDEX = 0;
	uint256 internal constant CALLTYPES_INDEX = 1;
	uint256 internal constant INIT_DATA_INDEX = 2;

	function installMultiType(address module, bytes calldata params) internal {
		(uint256[] calldata moduleTypeIds, bytes[] calldata data) = params.decodeMultiTypeInitData();

		uint256 length = moduleTypeIds.length;
		if (length != data.length) LengthMismatch.selector.revertWith();

		for (uint256 i; i < length; ) {
			uint256 moduleTypeId = moduleTypeIds[i];
			if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
				installValidator(module, data[i]);
			} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
				installExecutor(module, data[i]);
			} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
				installFallbackHandler(module, data[i]);
			} else if (moduleTypeId == MODULE_TYPE_HOOK) {
				installHook(module, data[i]);
			}

			unchecked {
				i = i + 1;
			}
		}
	}

	function installValidator(address validator, bytes calldata data) internal {
		validateModuleType(validator, MODULE_TYPE_VALIDATOR);

		SentinelList storage validators = getValidatorsList();
		if (validators.contains(validator)) ValidatorAlreadyInstalled.selector.revertWith(validator);

		validators.push(validator);
		invokeOnInstall(validator, data);
	}

	function uninstallValidator(address validator, bytes calldata data) internal {
		SentinelList storage validators = getValidatorsList();
		if (!validators.contains(validator)) ValidatorNotInstalled.selector.revertWith(validator);

		validators.pop(data.decodeAddress(0), validator);
		if (validators.isEmpty()) NoValidatorInstalled.selector.revertWith();

		invokeOnUninstall(validator, data.decodeBytes(1));
	}

	function installExecutor(address executor, bytes calldata data) internal {
		validateModuleType(executor, MODULE_TYPE_EXECUTOR);

		SentinelList storage executors = getExecutorsList();
		if (executors.contains(executor)) ExecutorAlreadyInstalled.selector.revertWith(executor);

		executors.push(executor);
		invokeOnInstall(executor, data);
	}

	function uninstallExecutor(address executor, bytes calldata data) internal {
		SentinelList storage executors = getExecutorsList();
		if (!executors.contains(executor)) ExecutorNotInstalled.selector.revertWith(executor);

		executors.pop(data.decodeAddress(0), executor);
		invokeOnUninstall(executor, data.decodeBytes(1));
	}

	function installFallbackHandler(address handler, bytes calldata data) internal {
		validateModuleType(handler, MODULE_TYPE_FALLBACK);

		(bytes4[] calldata selectors, CallType[] calldata callTypes, ) = decodeFallbackHandlerInputs(data);

		setFallbackHandler(handler, selectors, callTypes);
		invokeOnInstall(handler, data);
	}

	function uninstallFallbackHandler(address handler, bytes calldata data) internal {
		unsetFallbackHandler(data.decodeSelectors(0));
		invokeOnUninstall(handler, data.decodeBytes(1));
	}

	function setFallbackHandler(address handler, bytes4[] calldata selectors, CallType[] calldata callTypes) internal {
		// prettier-ignore
		assembly ("memory-safe") {
			let length := selectors.length
			if xor(length, callTypes.length) {
				mstore(0x00, 0xff633a38) // LengthMismatch()
				revert(0x1c, 0x04)
			}

			handler := shr(0x60, shl(0x60, handler))
			let selector
			let callType
			let derivedSlot

			for { let i } lt(i, length) { i := add(i, 0x01) } {
				selector := calldataload(add(selectors.offset, shl(0x05, i)))
				callType := calldataload(add(callTypes.offset, shl(0x05, i)))

				// 0x6d61fe70: onInstall(bytes)
				// 0x8a91b0e3: onUninstall(bytes)
				if or(iszero(selector), or(eq(selector, 0x6d61fe70), eq(selector, 0x8a91b0e3))) {
					mstore(0x00, 0x7352d91c) // InvalidSelector()
					revert(0x1c, 0x04)
				}

				// CALLTYPE_SINGLE: 0x00
				// CALLTYPE_STATIC: 0xFE
				// CALLTYPE_DELEGATE: 0xFF
				if and(iszero(iszero(callType)), and(xor(callType, shl(0xf8, 0xFF)), xor(callType, shl(0xf8, 0xFE)))) {
					mstore(0x00, 0x39d2eb55) // InvalidCallType()
					revert(0x1c, 0x04)
				}

				mstore(0x00, selector)
				mstore(0x20, FALLBACK_HANDLERS_STORAGE_SLOT)
				derivedSlot := keccak256(0x00, 0x40)

				if sload(derivedSlot) {
					let ptr := mload(0x40)
					mstore(ptr, 0xb014ac0800000000000000000000000000000000000000000000000000000000) // FallbackHandlerAlreadyInstalled(address,bytes4)
					mstore(add(ptr, 0x04), and(handler, 0xffffffffffffffffffffffffffffffffffffffff))
					mstore(add(ptr, 0x24), and(selector, 0xffffffff00000000000000000000000000000000000000000000000000000000))
					revert(ptr, 0x44)
				}

				sstore(derivedSlot, add(callType, handler))
			}
		}
	}

	function unsetFallbackHandler(bytes4[] calldata selectors) internal {
		assembly ("memory-safe") {
			let length := selectors.length
			let selector
			let derivedSlot

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				selector := calldataload(add(selectors.offset, shl(0x05, i)))

				mstore(0x00, selector)
				mstore(0x20, FALLBACK_HANDLERS_STORAGE_SLOT)
				derivedSlot := keccak256(0x00, 0x40)

				if iszero(sload(derivedSlot)) {
					mstore(0x00, 0x657f570200000000000000000000000000000000000000000000000000000000) // FallbackHandlerNotInstalled(bytes4)
					mstore(0x04, selector)
					revert(0x00, 0x24)
				}

				sstore(derivedSlot, 0x00)
			}
		}
	}

	function getFallbackHandler(bytes4 selector) internal view returns (CallType callType, address handler) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACK_HANDLERS_STORAGE_SLOT)

			let data := sload(keccak256(0x00, 0x40))
			if data {
				callType := data
				handler := shr(0x60, shl(0x60, data))
			}
		}
	}

	function decodeFallbackHandlerInputs(
		bytes calldata data
	) internal pure returns (bytes4[] calldata selectors, CallType[] calldata callTypes, bytes calldata initData) {
		assembly ("memory-safe") {
			function decode(l, o, i) -> length, offset {
				let lengthPtr := add(o, and(calldataload(add(o, shl(0x05, i))), 0xffffffff))
				length := and(calldataload(lengthPtr), 0xffffffff)
				offset := add(lengthPtr, 0x20)
			
				if lt(add(l, o), add(length, offset)) {
					mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
					revert(0x1c, 0x04)
				}
			}

			selectors.length, selectors.offset := decode(data.length, data.offset, SELECTORS_INDEX)
			callTypes.length, callTypes.offset := decode(data.length, data.offset, CALLTYPES_INDEX)
			initData.length, initData.offset := decode(data.length, data.offset, INIT_DATA_INDEX)
		}
	}

	function installHook(address hook, bytes calldata data) internal {
		validateModuleType(hook, MODULE_TYPE_HOOK);
		setHook(hook);
		invokeOnInstall(hook, data);
	}

	function uninstallHook(address hook, bytes calldata data) internal {
		unsetHook(hook);
		invokeOnUninstall(hook, data);
	}

	function setHook(address hook) internal {
		assembly ("memory-safe") {
			if sload(HOOK_STORAGE_SLOT) {
				mstore(0x00, 0x741cbe0300000000000000000000000000000000000000000000000000000000) // HookAlreadyInstalled(address)
				mstore(0x04, and(hook, 0xffffffffffffffffffffffffffffffffffffffff))
				revert(0x00, 0x24)
			}

			sstore(HOOK_STORAGE_SLOT, and(hook, 0xffffffffffffffffffffffffffffffffffffffff))
		}
	}

	function unsetHook(address hook) internal {
		assembly ("memory-safe") {
			if xor(sload(HOOK_STORAGE_SLOT), hook) {
				mstore(0x00, 0x2fd1f68800000000000000000000000000000000000000000000000000000000) // HookNotInstalled(address)
				mstore(0x04, and(hook, 0xffffffffffffffffffffffffffffffffffffffff))
				revert(0x00, 0x24)
			}

			sstore(HOOK_STORAGE_SLOT, 0x00)
		}
	}

	function getHook() internal view returns (address hook) {
		assembly ("memory-safe") {
			hook := sload(HOOK_STORAGE_SLOT)
		}
	}

	function invokeOnInstall(address module, bytes calldata data) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6d61fe7000000000000000000000000000000000000000000000000000000000) // onInstall(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), data.length)
			calldatacopy(add(ptr, 0x44), data.offset, data.length)

			if iszero(call(gas(), module, 0x00, ptr, add(data.length, 0x44), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function invokeOnUninstall(address module, bytes calldata data) internal returns (bool success) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8a91b0e300000000000000000000000000000000000000000000000000000000) // onUninstall(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), data.length)
			calldatacopy(add(ptr, 0x44), data.offset, data.length)

			success := call(gas(), module, 0x00, ptr, add(data.length, 0x44), 0x00, 0x00)
		}
	}

	function validateModuleType(address module, uint256 moduleTypeId) internal view {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xecd0596100000000000000000000000000000000000000000000000000000000) // isModuleType(uint256)
			mstore(add(ptr, 0x04), moduleTypeId)

			if iszero(staticcall(gas(), module, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			if iszero(mload(0x00)) {
				mstore(0x00, 0x098312d200000000000000000000000000000000000000000000000000000000) // InvalidModuleTypeId(uint256)
				mstore(0x04, moduleTypeId)
				revert(0x00, 0x24)
			}
		}
	}

	function isValidatorInstalled(address validator) internal view returns (bool) {
		return getValidatorsList().contains(validator);
	}

	function isExecutorInstalled(address executor) internal view returns (bool) {
		return getExecutorsList().contains(executor);
	}

	function isFallbackHandlerInstalled(bytes4 selector) internal view returns (bool flag) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACK_HANDLERS_STORAGE_SLOT)

			flag := iszero(iszero(sload(keccak256(0x00, 0x40))))
		}
	}

	function isFallbackHandlerInstalled(address handler, bytes4 selector) internal view returns (bool flag) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACK_HANDLERS_STORAGE_SLOT)

			flag := eq(and(sload(keccak256(0x00, 0x40)), 0xffffffffffffffffffffffffffffffffffffffff), handler)
		}
	}

	function isHookInstalled() internal view returns (bool flag) {
		assembly ("memory-safe") {
			flag := iszero(iszero(sload(HOOK_STORAGE_SLOT)))
		}
	}

	function isHookInstalled(address hook) internal view returns (bool flag) {
		assembly ("memory-safe") {
			flag := eq(sload(HOOK_STORAGE_SLOT), hook)
		}
	}

	function getValidatorsList() internal pure returns (SentinelList storage $) {
		assembly ("memory-safe") {
			$.slot := VALIDATORS_STORAGE_SLOT
		}
	}

	function getExecutorsList() internal pure returns (SentinelList storage $) {
		assembly ("memory-safe") {
			$.slot := EXECUTORS_STORAGE_SLOT
		}
	}
}
