// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {CallType, ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/Types.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title AccountModule

contract AccountModule is RegistryAdapter {
	using CalldataDecoder for bytes;
	using ModuleTypeLib for ModuleType[];

	/// @dev keccak256("ModuleInstalled(uint256,address)")
	bytes32 internal constant MODULE_INSTALLED_TOPIC =
		0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123;

	/// @dev keccak256("ModuleUninstalled(uint256,address)")
	bytes32 internal constant MODULE_UNINSTALLED_TOPIC =
		0x341347516a9de374859dfda710fa4828b2d48cb57d4fbe4c1149612b8e02276e;

	/// @dev keccak256("RootValidatorConfigured(address)")
	bytes32 internal constant ROOT_VALIDATOR_CONFIGURED_TOPIC =
		0xdba94517c2e4d2bd67ab2d9e679f0a166a27f8026e070545b1b1f06742459778;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.fallbacks")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant FALLBACKS_STORAGE_SLOT =
		0x2500be8b097cabc8fbfb1f2a0e1495cf45ecf83bbba382f7125760d2d2920d00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.modules")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant MODULES_STORAGE_SLOT = 0xd5c15c7f662d752f82270246f0c46945931f1cea1e031d18e20309be7f4e2d00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.module.root-validator")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant ROOT_VALIDATOR_STORAGE_SLOT =
		0x67598b9e643ef9938aad3488e233ee534c849d31623840967673479f8f973800;

	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	bytes1 internal constant FLAG_DEFAULT = 0x00;
	bytes1 internal constant FLAG_ENFORCE = 0xFF;

	constructor() {
		_setRootValidator(SENTINEL);
	}

	function _rootValidator() internal view virtual returns (address validator) {
		assembly ("memory-safe") {
			validator := sload(ROOT_VALIDATOR_STORAGE_SLOT)
		}
	}

	function _configureRootValidator(address validator, bytes calldata data) internal virtual {
		if (!_isInitialized(validator)) _installModule(MODULE_TYPE_VALIDATOR, validator, data);
		_setRootValidator(validator);
	}

	function _setRootValidator(address validator) private {
		assembly ("memory-safe") {
			validator := shr(0x60, shl(0x60, validator))
			sstore(ROOT_VALIDATOR_STORAGE_SLOT, validator)
			log2(0x00, 0x00, ROOT_VALIDATOR_CONFIGURED_TOPIC, validator)
		}
	}

	function _hook(address target) internal view virtual returns (address hook) {
		assembly ("memory-safe") {
			target := shr(0x60, shl(0x60, target))
			mstore(0x00, target)
			mstore(0x20, MODULES_STORAGE_SLOT)

			hook := shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))

			if iszero(hook) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, target)
				revert(0x1c, 0x24)
			}
		}
	}

	function _getConfiguration(
		address module
	) internal view virtual returns (ModuleType moduleTypeId, PackedModuleTypes packedTypes, address hook) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, module)))
			mstore(0x20, MODULES_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))
			moduleTypeId := shr(0xf8, configuration)
			packedTypes := shr(0xe0, shl(0x08, configuration))
			hook := shr(0x60, shl(0x60, configuration))
		}
	}

	function _fallbackHandler(bytes4 selector) internal view virtual returns (CallType callType, address handler) {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))
			if configuration {
				callType := shl(0xf8, shr(0xf8, configuration))
				handler := shr(0x60, shl(0x60, configuration))
			}
		}
	}

	function _installModule(ModuleType moduleTypeId, address module, bytes calldata data) internal virtual {
		ModuleType[] calldata moduleTypeIds;
		assembly ("memory-safe") {
			if iszero(module) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

			if iszero(data.length) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let ptr := add(data.offset, calldataload(data.offset))
			moduleTypeIds.length := calldataload(ptr)
			moduleTypeIds.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			data.length := calldataload(ptr)
			data.offset := add(ptr, 0x20)
		}

		PackedModuleTypes packedTypeIds = moduleTypeIds.encode();
		require(
			packedTypeIds.isType(moduleTypeId) && _checkModuleTypeIds(module, moduleTypeIds),
			Errors.InvalidModuleTypeId(moduleTypeId)
		);

		address hook;
		bytes calldata hookData;

		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))

			switch moduleTypeId
			// MODULE_TYPE_HOOK: 0x04
			case 0x04 {
				mstore(0x20, MODULES_STORAGE_SLOT)
				mstore(0x00, shr(0x60, shl(0x60, ENTRYPOINT)))

				let slot := keccak256(0x00, 0x40)
				hook := shr(0x60, shl(0x60, sload(slot)))

				if and(hook, xor(hook, SENTINEL)) {
					mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
					mstore(0x20, hook)
					revert(0x1c, 0x24)
				}

				let configuration := add(add(shl(0xf8, moduleTypeId), shl(0xd8, packedTypeIds)), module)

				sstore(slot, configuration)

				mstore(0x00, shr(0x60, shl(0x60, address())))
				sstore(keccak256(0x00, 0x40), configuration)

				if data.length {
					let ptr := add(data.offset, calldataload(data.offset))
					data.length := calldataload(ptr)
					data.offset := add(ptr, 0x20)
				}

				hook := SENTINEL
				hookData.offset := 0x00
				hookData.length := 0x00
			}
			default {
				mstore(0x00, module)
				mstore(0x20, MODULES_STORAGE_SLOT)

				let slot := keccak256(0x00, 0x40)

				if sload(slot) {
					mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
					mstore(0x20, module)
					revert(0x1c, 0x24)
				}

				let ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
				hookData.length := calldataload(ptr)
				hookData.offset := add(ptr, 0x20)

				if iszero(lt(hookData.length, 0x14)) {
					hook := shr(0x60, calldataload(hookData.offset))
					hookData.offset := add(hookData.offset, 0x14)
					hookData.length := sub(hookData.length, 0x14)
				}

				ptr := add(data.offset, calldataload(data.offset))
				data.length := calldataload(ptr)
				data.offset := add(ptr, 0x20)

				if iszero(hook) {
					hook := SENTINEL
				}

				sstore(slot, add(add(shl(0xf8, moduleTypeId), shl(0xd8, packedTypeIds)), hook))
			}
		}

		if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes4[] calldata selectors;
			CallType[] calldata callTypes;
			bytes1 flag;
			(selectors, callTypes, flag, data) = data.decodeFallbackInstall();

			_installFallback(module, selectors, callTypes, flag);
		}

		if (!_isInitialized(module)) _onInstall(module, moduleTypeId, data);
		if (hook != SENTINEL && !_isInitialized(hook)) _onInstall(hook, MODULE_TYPE_HOOK, hookData);
	}

	function _uninstallModule(ModuleType moduleTypeId, address module, bytes calldata data) internal virtual {
		address hook;
		bytes calldata hookData;

		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))

			if iszero(extcodesize(module)) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

			hookData.offset := 0x00
			hookData.length := 0x00

			switch moduleTypeId
			// MODULE_TYPE_HOOK: 0x04
			case 0x04 {
				mstore(0x20, MODULES_STORAGE_SLOT)
				mstore(0x00, shr(0x60, shl(0x60, ENTRYPOINT)))

				let slot := keccak256(0x00, 0x40)

				if xor(module, shr(0x60, shl(0x60, sload(slot)))) {
					mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
					mstore(0x20, module)
					revert(0x1c, 0x24)
				}

				sstore(slot, SENTINEL)

				mstore(0x00, shr(0x60, shl(0x60, address())))
				sstore(keccak256(0x00, 0x40), SENTINEL)

				hook := SENTINEL

				if data.length {
					let ptr := add(data.offset, calldataload(data.offset))
					data.length := calldataload(ptr)
					data.offset := add(ptr, 0x20)
				}
			}
			default {
				mstore(0x00, module)
				mstore(0x20, MODULES_STORAGE_SLOT)

				let slot := keccak256(0x00, 0x40)
				let configuration := sload(slot)

				hook := shr(0x60, shl(0x60, configuration))

				if iszero(hook) {
					mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
					mstore(0x20, module)
					revert(0x1c, 0x24)
				}

				if xor(moduleTypeId, shr(0xf8, configuration)) {
					mstore(0x00, 0x098312d2) // InvalidModuleTypeId(uint256)
					mstore(0x20, moduleTypeId)
					revert(0x1c, 0x24)
				}

				sstore(slot, 0x00)

				if data.length {
					let ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
					hookData.length := calldataload(ptr)
					hookData.offset := add(ptr, 0x20)

					ptr := add(data.offset, calldataload(data.offset))
					data.length := calldataload(ptr)
					data.offset := add(ptr, 0x20)
				}
			}
		}

		if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes4[] calldata selectors;
			bytes1 flag;
			(selectors, flag, data) = data.decodeFallbackUninstall();

			_uninstallFallback(selectors, flag);
		}

		_onUninstall(module, moduleTypeId, data);
		if (hook != SENTINEL) _onUninstall(hook, MODULE_TYPE_HOOK, hookData);
	}

	function _isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) internal view virtual returns (bool result) {
		result = moduleTypeId != MODULE_TYPE_FALLBACK
			? _isModuleInstalled(moduleTypeId, module)
			: _isModuleInstalled(moduleTypeId, module) && _isFallbackInstalled(module, data.decodeSelector());
	}

	function _isModuleInstalled(ModuleType moduleTypeId, address module) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			switch moduleTypeId
			case 0x04 {
				mstore(0x00, shr(0x60, shl(0x60, ENTRYPOINT)))
				mstore(0x20, MODULES_STORAGE_SLOT)
				result := eq(module, shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40)))))
			}
			default {
				mstore(0x00, shr(0x60, shl(0x60, module)))
				mstore(0x20, MODULES_STORAGE_SLOT)
				result := iszero(iszero(shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))))
			}
		}
	}

	function _installFallback(
		address module,
		bytes4[] calldata selectors,
		CallType[] calldata callTypes,
		bytes1 flag
	) internal virtual {
		assembly ("memory-safe") {
			if xor(selectors.length, callTypes.length) {
				mstore(0x00, 0xff633a38) // LengthMismatch()
				revert(0x1c, 0x04)
			}

			if and(flag, xor(flag, FLAG_ENFORCE)) {
				mstore(0x00, 0x3ea063d0) // InvalidFlag()
				revert(0x1c, 0x04)
			}

			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let callType
			let selector
			let slot

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
				selector := shr(0xe0, calldataload(add(selectors.offset, shl(0x05, i))))
				callType := shr(0xf8, calldataload(add(callTypes.offset, shl(0x05, i))))

				// 0x6d61fe70: onInstall(bytes) | 0x8a91b0e3: onUninstall(bytes)
				if or(iszero(selector), or(eq(selector, 0x6d61fe70), eq(selector, 0x8a91b0e3))) {
					mstore(0x00, 0x7352d91c) // ForbiddenSelector()
					revert(0x1c, 0x04)
				}

				// CALLTYPE_SINGLE: 0x00 | CALLTYPE_STATIC: 0xFE | CALLTYPE_DELEGATE: 0xFF
				if iszero(or(iszero(callType), or(eq(callType, 0xFE), eq(callType, 0xFF)))) {
					mstore(0x00, 0x853e38d3) // UnsupportedCallType(bytes1)
					mstore(0x20, shl(0xf8, callType))
					revert(0x1c, 0x24)
				}

				mstore(0x00, shl(0xe0, selector))
				slot := keccak256(0x00, 0x40)

				if xor(flag, FLAG_ENFORCE) {
					if sload(slot) {
						mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
						mstore(0x20, module)
						revert(0x1c, 0x24)
					}
				}

				sstore(slot, add(shl(0xf8, callType), module))
			}
		}
	}

	function _uninstallFallback(bytes4[] calldata selectors, bytes1 flag) internal virtual {
		assembly ("memory-safe") {
			if and(flag, xor(flag, FLAG_ENFORCE)) {
				mstore(0x00, 0x3ea063d0) // InvalidFlag()
				revert(0x1c, 0x04)
			}

			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let selector
			let slot

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
				selector := shr(0xe0, shl(0xe0, calldataload(add(selectors.offset, shl(0x05, i)))))

				mstore(0x00, selector)
				slot := keccak256(0x00, 0x40)

				if xor(flag, FLAG_ENFORCE) {
					if iszero(sload(slot)) {
						mstore(0x00, 0xc2a825f5) // UnknownSelector(bytes4)
						mstore(0x20, selector)
						revert(0x1c, 0x24)
					}
				}

				sstore(slot, 0x00)
			}
		}
	}

	function _isFallbackInstalled(address handler, bytes4 selector) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shl(0xe0, shr(0xe0, selector)))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)
			result := eq(handler, shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40)))))
		}
	}

	function _checkModule(address module, ModuleType moduleTypeId) internal view virtual {
		assembly ("memory-safe") {
			if or(iszero(moduleTypeId), and(gt(moduleTypeId, 0x04), xor(moduleTypeId, 0x07))) {
				mstore(0x00, 0x41c38b30) // UnsupportedModuleType(uint256)
				mstore(0x20, moduleTypeId)
				revert(0x1c, 0x24)
			}

			module := shr(0x60, shl(0x60, module))
			switch moduleTypeId
			case 0x04 {
				mstore(0x00, shr(0x60, shl(0x60, ENTRYPOINT)))
				mstore(0x20, MODULES_STORAGE_SLOT)

				if xor(module, shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))) {
					mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
					mstore(0x20, module)
					revert(0x1c, 0x24)
				}
			}
			default {
				mstore(0x00, module)
				mstore(0x20, MODULES_STORAGE_SLOT)

				let configuration := sload(keccak256(0x00, 0x40))

				if iszero(shr(0x60, shl(0x60, configuration))) {
					mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
					mstore(0x20, module)
					revert(0x1c, 0x24)
				}

				if xor(moduleTypeId, shr(0xf8, configuration)) {
					mstore(0x00, 0x098312d2) // InvalidModuleTypeId(uint256)
					mstore(0x20, moduleTypeId)
					revert(0x1c, 0x24)
				}
			}
		}
	}

	function _onInstall(address module, ModuleType moduleTypeId, bytes calldata data) private {
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

	function _onUninstall(address module, ModuleType moduleTypeId, bytes calldata data) private {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8a91b0e300000000000000000000000000000000000000000000000000000000) // onUninstall(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), data.length)
			calldatacopy(add(ptr, 0x44), data.offset, data.length)

			if iszero(call(gas(), module, 0x00, ptr, add(data.length, 0x44), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			log3(0x00, 0x00, MODULE_UNINSTALLED_TOPIC, moduleTypeId, module)
		}
	}

	function _isInitialized(address module) private view returns (bool result) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd60b347f00000000000000000000000000000000000000000000000000000000) // isInitialized(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))

			if iszero(staticcall(gas(), module, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			result := mload(0x00)
		}
	}

	function _checkModuleTypeIds(
		address module,
		ModuleType[] calldata moduleTypeIds
	) private view returns (bool result) {
		if (moduleTypeIds.length == 1 && moduleTypeIds[0] == MODULE_TYPE_HOOK && module == SENTINEL) return true;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xecd0596100000000000000000000000000000000000000000000000000000000) // isModuleType(uint256)

			// prettier-ignore
			for { let i } lt(i, moduleTypeIds.length) { i := add(i, 0x01) } {
				let moduleTypeId := calldataload(add(moduleTypeIds.offset, shl(0x05, i)))

				if or(iszero(moduleTypeId), and(gt(moduleTypeId, 0x04), xor(moduleTypeId, 0x07))) {
					mstore(0x00, 0x41c38b30) // UnsupportedModuleType(uint256)
					mstore(0x20, moduleTypeId)
					revert(0x1c, 0x24)
				}

				mstore(add(ptr, 0x04), moduleTypeId)

				if iszero(staticcall(gas(), module, ptr, 0x24, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				result := mload(0x00)
				if iszero(result) { break }
			}
		}
	}
}
