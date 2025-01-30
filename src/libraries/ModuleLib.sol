// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType} from "src/types/ExecutionMode.sol";
import {SentinelList} from "src/types/SentinelList.sol";
import {BytesLib} from "./BytesLib.sol";
import {CalldataDecoder} from "./CalldataDecoder.sol";
import {CustomRevert} from "./CustomRevert.sol";

/// @title ModuleLib
/// @notice Provides functions to handle the management of ERC-7579 modules

library ModuleLib {
	using BytesLib for bytes;
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;

	error UnsupportedModuleType(uint256 moduleTypeId);

	error InvalidModule(address module);
	error InvalidModuleTypeId(uint256 moduleTypeId);

	error ModuleAlreadyInstalled(address module);
	error ModuleNotInstalled(address module);

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

	/// @dev keccak256(bytes("ModuleInstalled(uint256,address)"))
	bytes32 private constant MODULE_INSTALLED_TOPIC =
		0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123;

	/// @dev keccak256(bytes("ModuleUninstalled(uint256,address)"))
	bytes32 private constant MODULE_UNINSTALLED_TOPIC =
		0x341347516a9de374859dfda710fa4828b2d48cb57d4fbe4c1149612b8e02276e;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.validators")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant VALIDATORS_STORAGE_SLOT =
		0xf2c1f63b10845c1394082ccd2352280b1281c904a50557aad80ff67eca1ddb00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.executors")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant EXECUTORS_STORAGE_SLOT =
		0xf9162d146b6422df1bb2630e4e3d64a305decb164733850b4dcfd08f5c72b800;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.fallbackHandlers")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant FALLBACKS_STORAGE_SLOT =
		0xe9bbfc6a7c1b005e63cb26d446b1154a357dd2dded84acdf0558b07639dcb300;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.hook")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant HOOK_STORAGE_SLOT = 0xaf4f685d452ea61d76faaeadc5c73cbfc37c47e989c36c89cfc7f80215867800;

	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;
	uint256 internal constant MODULE_TYPE_POLICY = 5;
	uint256 internal constant MODULE_TYPE_SIGNER = 6;

	function installValidator(address validator, bytes calldata data) internal {
		validateModuleType(validator, MODULE_TYPE_VALIDATOR);

		SentinelList storage validators = getValidatorsList();
		if (validators.contains(validator)) ValidatorAlreadyInstalled.selector.revertWith(validator);

		validators.push(validator);
		invokeOnInstall(validator, MODULE_TYPE_VALIDATOR, data);
	}

	function uninstallValidator(address validator, bytes calldata data) internal {
		SentinelList storage validators = getValidatorsList();
		if (!validators.contains(validator)) ValidatorNotInstalled.selector.revertWith(validator);

		validators.pop(data.toAddress(0), validator);
		if (validators.isEmpty()) NoValidatorInstalled.selector.revertWith();

		invokeOnUninstall(validator, MODULE_TYPE_VALIDATOR, data.toBytes(1));
	}

	function installExecutor(address executor, bytes calldata data) internal {
		validateModuleType(executor, MODULE_TYPE_EXECUTOR);

		SentinelList storage executors = getExecutorsList();
		if (executors.contains(executor)) ExecutorAlreadyInstalled.selector.revertWith(executor);

		executors.push(executor);
		invokeOnInstall(executor, MODULE_TYPE_EXECUTOR, data);
	}

	function uninstallExecutor(address executor, bytes calldata data) internal {
		SentinelList storage executors = getExecutorsList();
		if (!executors.contains(executor)) ExecutorNotInstalled.selector.revertWith(executor);

		executors.pop(data.toAddress(0), executor);
		invokeOnUninstall(executor, MODULE_TYPE_EXECUTOR, data.toBytes(1));
	}

	function installFallback(address handler, bytes calldata data) internal {
		validateModuleType(handler, MODULE_TYPE_FALLBACK);

		(bytes4[] calldata selectors, CallType[] calldata callTypes) = data.decodeSelectorsAndCallTypes();

		_installFallback(handler, selectors, callTypes);
		invokeOnInstall(handler, MODULE_TYPE_FALLBACK, data);
	}

	function uninstallFallback(address handler, bytes calldata data) internal {
		_uninstallFallback(data.decodeSelectors(0));
		invokeOnUninstall(handler, MODULE_TYPE_FALLBACK, data.toBytes(1));
	}

	function _installFallback(address handler, bytes4[] calldata selectors, CallType[] calldata callTypes) private {
		assembly ("memory-safe") {
			if xor(selectors.length, callTypes.length) {
				mstore(0x00, 0xff633a38) // LengthMismatch()
				revert(0x1c, 0x04)
			}

			let callType
			let selector
			let slot

			handler := shr(0x60, shl(0x60, handler))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
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
				slot := keccak256(0x00, 0x40)

				if sload(slot) {
					let ptr := mload(0x40)
					mstore(ptr, 0xb014ac0800000000000000000000000000000000000000000000000000000000) // FallbackHandlerAlreadyInstalled(address,bytes4)
					mstore(add(ptr, 0x04), handler)
					mstore(add(ptr, 0x24), selector)
					revert(ptr, 0x44)
				}

				sstore(slot, add(callType, handler))
			}
		}
	}

	function _uninstallFallback(bytes4[] calldata selectors) private {
		assembly ("memory-safe") {
			let selector
			let slot

			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
				selector := shr(0xe0, shl(0xe0, calldataload(add(selectors.offset, shl(0x05, i)))))

				mstore(0x00, selector)
				slot := keccak256(0x00, 0x40)

				if iszero(sload(slot)) {
					mstore(0x00, 0xc2a825f5) // UnknownSelector(bytes4)
					mstore(0x20, selector)
					revert(0x1c, 0x24)
				}

				sstore(slot, 0x00)
			}
		}
	}

	function getFallback(bytes4 selector) internal view returns (CallType callType, address handler) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let stored := sload(keccak256(0x00, 0x40))
			if stored {
				callType := stored
				handler := shr(0x60, shl(0x60, stored))
			}
		}
	}

	function installHook(address hook, bytes calldata data) internal {
		validateModuleType(hook, MODULE_TYPE_HOOK);
		_installHook(hook);
		invokeOnInstall(hook, MODULE_TYPE_HOOK, data);
	}

	function uninstallHook(address hook, bytes calldata data) internal {
		_uninstallHook(hook);
		invokeOnUninstall(hook, MODULE_TYPE_HOOK, data);
	}

	function _installHook(address hook) private {
		assembly ("memory-safe") {
			hook := shr(0x60, shl(0x60, hook))
			if sload(HOOK_STORAGE_SLOT) {
				mstore(0x00, 0x741cbe03) // HookAlreadyInstalled(address)
				mstore(0x20, hook)
				revert(0x1c, 0x24)
			}

			sstore(HOOK_STORAGE_SLOT, hook)
		}
	}

	function _uninstallHook(address hook) private {
		assembly ("memory-safe") {
			if xor(sload(HOOK_STORAGE_SLOT), hook) {
				mstore(0x00, 0x2fd1f688) // HookNotInstalled(address)
				mstore(0x20, shr(0x60, shl(0x60, hook)))
				revert(0x1c, 0x24)
			}

			sstore(HOOK_STORAGE_SLOT, 0x00)
		}
	}

	function getHook() internal view returns (address hook) {
		assembly ("memory-safe") {
			hook := sload(HOOK_STORAGE_SLOT)
		}
	}

	function invokeOnInstall(address module, uint256 moduleTypeId, bytes calldata data) internal {
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

			log3(0x00, 0x00, MODULE_INSTALLED_TOPIC, moduleTypeId, module)
		}
	}

	function invokeOnUninstall(
		address module,
		uint256 moduleTypeId,
		bytes calldata data
	) internal returns (bool success) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8a91b0e300000000000000000000000000000000000000000000000000000000) // onUninstall(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), data.length)
			calldatacopy(add(ptr, 0x44), data.offset, data.length)

			success := call(gas(), module, 0x00, ptr, add(data.length, 0x44), 0x00, 0x00)

			if success {
				log3(0x00, 0x00, MODULE_UNINSTALLED_TOPIC, moduleTypeId, module)
			}
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
				mstore(0x00, 0x098312d2) // InvalidModuleTypeId(uint256)
				mstore(0x20, moduleTypeId)
				revert(0x1c, 0x24)
			}
		}
	}

	function isValidatorInstalled(address validator) internal view returns (bool) {
		return getValidatorsList().contains(validator);
	}

	function isExecutorInstalled(address executor) internal view returns (bool) {
		return getExecutorsList().contains(executor);
	}

	function isFallbackInstalled(bytes4 selector) internal view returns (bool flag) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACKS_STORAGE_SLOT)
			flag := iszero(iszero(sload(keccak256(0x00, 0x40))))
		}
	}

	function isFallbackInstalled(address handler, bytes4 selector) internal view returns (bool flag) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACKS_STORAGE_SLOT)
			flag := eq(shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40)))), shr(0x60, shl(0x60, handler)))
		}
	}

	function isHookInstalled() internal view returns (bool flag) {
		assembly ("memory-safe") {
			flag := iszero(iszero(sload(HOOK_STORAGE_SLOT)))
		}
	}

	function isHookInstalled(address hook) internal view returns (bool flag) {
		assembly ("memory-safe") {
			flag := eq(sload(HOOK_STORAGE_SLOT), shr(0x60, shl(0x60, hook)))
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
