// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Arrays} from "src/libraries/Arrays.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {CallType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";
import {AccessControl} from "./AccessControl.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title ModuleManager

abstract contract ModuleManager is AccessControl, RegistryAdapter {
	using Arrays for address[];
	using Arrays for bytes4[];
	using Arrays for bytes32[];
	using CalldataDecoder for bytes;

	/// @dev keccak256("ModuleInstalled(uint256,address)")
	bytes32 private constant MODULE_INSTALLED_TOPIC =
		0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123;

	/// @dev keccak256("ModuleUninstalled(uint256,address)")
	bytes32 private constant MODULE_UNINSTALLED_TOPIC =
		0x341347516a9de374859dfda710fa4828b2d48cb57d4fbe4c1149612b8e02276e;

	/// @dev keccak256("HookConfigured(address,address)")
	bytes32 private constant HOOK_CONFIGURED_TOPIC = 0x7943f325758c39995376016e658e4b46aec4e80ae304303cb83ef55552e3d459;

	/// @dev keccak256("RootValidatorConfigured(address)")
	bytes32 private constant ROOT_VALIDATOR_CONFIGURED_TOPIC =
		0xdba94517c2e4d2bd67ab2d9e679f0a166a27f8026e070545b1b1f06742459778;

	/// @dev keccak256("SelectorConfigured(address,bytes4,bool)")
	bytes32 private constant SELECTOR_CONFIGURED_TOPIC =
		0xf27e6a44b456e1a46611dc7f57371c1d131569d7dbca917ffff74064dd420680;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.modules")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant MODULES_STORAGE_SLOT = 0xd5c15c7f662d752f82270246f0c46945931f1cea1e031d18e20309be7f4e2d00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.fallbacks")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant FALLBACKS_STORAGE_SLOT =
		0x2500be8b097cabc8fbfb1f2a0e1495cf45ecf83bbba382f7125760d2d2920d00;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.globalHooks")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant GLOBAL_HOOKS_STORAGE_SLOT =
		0x28bf1e00ee6cd006e47ac59e39d56c78a824b4f5cdb34d6efeee7e2d8ed72500;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.account.rootValidator")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant ROOT_VALIDATOR_STORAGE_SLOT =
		0x2e9b08cce67043ff1c01b06b55dd0c57575ab55ed0463d942433873430f02000;

	bytes1 internal constant FLAG_DEFAULT = 0x00;
	bytes1 internal constant FLAG_SKIP = 0x01;
	bytes1 internal constant FLAG_ENFORCE = 0xFF;

	function _configureRootValidator(address validator, bytes calldata data) internal virtual {
		if (!_isModuleInstalled(MODULE_TYPE_VALIDATOR, validator, data)) {
			_installModule(MODULE_TYPE_VALIDATOR, validator, data);
		}

		assembly ("memory-safe") {
			if iszero(extcodesize(validator)) {
				mstore(0x00, 0xefc0ad37) // InvalidRootValidator()
				revert(0x1c, 0x04)
			}

			validator := shr(0x60, shl(0x60, validator))
			sstore(ROOT_VALIDATOR_STORAGE_SLOT, validator)
			log2(0x00, 0x00, ROOT_VALIDATOR_CONFIGURED_TOPIC, validator)
		}
	}

	function _rootValidator() internal view virtual returns (address validator) {
		assembly ("memory-safe") {
			validator := sload(ROOT_VALIDATOR_STORAGE_SLOT)
		}
	}

	function _globalHooks() internal view virtual returns (address[] memory hooks) {
		assembly ("memory-safe") {
			hooks := mload(0x40)

			let offset := add(hooks, 0x20)
			let length := sload(GLOBAL_HOOKS_STORAGE_SLOT)

			mstore(hooks, length)
			mstore(0x40, add(offset, shl(0x05, length)))

			mstore(0x00, GLOBAL_HOOKS_STORAGE_SLOT)
			let slot := keccak256(0x00, 0x20)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(offset, shl(0x05, i)), sload(add(slot, i)))
			}
		}
	}

	function _getHook(address module) internal view virtual returns (address hook) {
		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))

			mstore(0x00, module)
			mstore(0x20, MODULES_STORAGE_SLOT)

			hook := shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))

			if iszero(hook) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, module)
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

			if configuration {
				moduleTypeId := shr(0xf8, configuration)
				packedTypes := shr(0xe0, shl(0x08, configuration))
				hook := shr(0x60, shl(0x60, configuration))
			}
		}
	}

	function _fallbackHandler(bytes4 selector) internal view virtual returns (CallType callType, address handler) {
		assembly ("memory-safe") {
			mstore(0x00, shl(0xe0, shr(0xe0, selector)))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))

			if configuration {
				callType := shl(0xf8, shr(0xf8, configuration))
				handler := shr(0x60, shl(0x60, configuration))
			}
		}
	}

	function _installModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) internal virtual withRegistry(module, moduleTypeId) {
		PackedModuleTypes packedTypes;
		address hook;
		bytes calldata hookData;
		(packedTypes, data, hook, hookData) = data.decodeInstallModuleParams();

		_checkModuleTypes(module, moduleTypeId, packedTypes);

		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))

			mstore(0x00, module)
			mstore(0x20, MODULES_STORAGE_SLOT)

			let slot := keccak256(0x00, 0x40)

			if sload(slot) {
				mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
				mstore(0x20, module)
				revert(0x1c, 0x24)
			}

			sstore(slot, or(or(shl(0xf8, moduleTypeId), shl(0xd8, packedTypes)), hook))
			log3(0x00, 0x00, HOOK_CONFIGURED_TOPIC, module, hook)
		}

		if (moduleTypeId == MODULE_TYPE_HOOK) {
			_installGlobalHook(module);
		}

		if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes32[] calldata selectors;
			bytes1 flag;
			(selectors, flag, data) = data.decodeFallbackParams();

			_checkSelectors(_processSelectors(selectors), _forbiddenSelectors());
			_installFallback(module, flag, selectors);
		}

		if (!_isInitialized(module)) _invokeOnInstall(module, moduleTypeId, data);
		if (hook != SENTINEL && !_isInitialized(hook)) _invokeOnInstall(hook, MODULE_TYPE_HOOK, hookData);
	}

	function _uninstallModule(ModuleType moduleTypeId, address module, bytes calldata data) internal virtual {
		address hook;
		bytes calldata hookData;
		(data, hookData) = data.decodeUninstallModuleParams();

		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))

			if iszero(extcodesize(module)) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

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
				mstore(0x00, 0x2125deae) // InvalidModuleType()
				revert(0x1c, 0x04)
			}

			sstore(slot, 0x00)
			log3(0x00, 0x00, HOOK_CONFIGURED_TOPIC, module, 0x00)
		}

		if (moduleTypeId == MODULE_TYPE_HOOK) {
			_uninstallGlobalHook(module);
		}

		if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes32[] calldata selectors;
			bytes1 flag;
			(selectors, flag, data) = data.decodeFallbackParams();

			_uninstallFallback(module, flag, selectors);
		}

		if (_isInitialized(module)) _invokeOnUninstall(module, moduleTypeId, data);
		if (hook != SENTINEL && _isInitialized(hook)) _invokeOnUninstall(hook, MODULE_TYPE_HOOK, hookData);
	}

	function _isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) internal view virtual returns (bool result) {
		result = moduleTypeId == MODULE_TYPE_FALLBACK
			? _isModuleInstalled(moduleTypeId, module) && _isFallbackInstalled(module, additionalContext)
			: moduleTypeId == MODULE_TYPE_HOOK
			? _isModuleInstalled(moduleTypeId, module) && _isGlobalHookInstalled(module)
			: _isModuleInstalled(moduleTypeId, module);
	}

	function _isModuleInstalled(ModuleType moduleTypeId, address module) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, module)))
			mstore(0x20, MODULES_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))

			if configuration {
				result := and(
					iszero(iszero(shr(0x60, shl(0x60, configuration)))),
					eq(moduleTypeId, shr(0xf8, configuration))
				)
			}
		}
	}

	function _installGlobalHook(address hook) internal virtual {
		address[] memory hooks = _globalHooks();
		bool exists = hooks.inSorted(hook);

		assembly ("memory-safe") {
			if exists {
				mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
				mstore(0x20, hook)
				revert(0x1c, 0x24)
			}

			let length := mload(hooks)
			mstore(hooks, add(length, 0x01))
			mstore(add(add(hooks, 0x20), shl(0x05, length)), hook)
		}

		_setGlobalHooks(hooks);
	}

	function _uninstallGlobalHook(address hook) internal virtual {
		address[] memory hooks = _globalHooks();
		(bool exists, uint256 index) = hooks.searchSorted(hook);

		assembly ("memory-safe") {
			if iszero(exists) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, hook)
				revert(0x1c, 0x24)
			}

			let offset := add(hooks, 0x20)
			let length := sub(mload(hooks), 0x01)
			mstore(add(offset, shl(0x05, index)), mload(add(offset, shl(0x05, length))))
			mstore(hooks, length)
		}

		_setGlobalHooks(hooks);
	}

	function _setGlobalHooks(address[] memory hooks) internal virtual {
		hooks.insertionSort();
		hooks.uniquifySorted();

		assembly ("memory-safe") {
			let offset := add(hooks, 0x20)
			let length := mload(hooks)
			sstore(GLOBAL_HOOKS_STORAGE_SLOT, length)

			mstore(0x00, GLOBAL_HOOKS_STORAGE_SLOT)
			let slot := keccak256(0x00, 0x20)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				sstore(add(slot, i), mload(add(offset, shl(0x05, i))))
			}
		}
	}

	function _isGlobalHookInstalled(address hook) internal view virtual returns (bool result) {
		return _globalHooks().inSorted(hook);
	}

	function _installFallback(address handler, bytes1 flag, bytes32[] calldata configurations) internal virtual {
		assembly ("memory-safe") {
			if iszero(or(iszero(flag), eq(flag, FLAG_ENFORCE))) {
				mstore(0x00, 0x3ea063d0) // InvalidFlag()
				revert(0x1c, 0x04)
			}

			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			// prettier-ignore
			for { let i } lt(i, configurations.length) { i := add(i, 0x01) } {
				let configuration := calldataload(add(configurations.offset, shl(0x05, i)))
				let callType := shr(0xf8, shl(0x20, configuration))
				let selector := shl(0xe0, shr(0xe0, configuration))

				// CALLTYPE_SINGLE: 0x00 | CALLTYPE_STATIC: 0xFE | CALLTYPE_DELEGATE: 0xFF
				if iszero(or(iszero(callType), or(eq(callType, 0xFE), eq(callType, 0xFF)))) {
					mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
					mstore(0x20, shl(0xf8, callType))
					revert(0x1c, 0x24)
				}

				mstore(0x00, selector)
				let slot := keccak256(0x00, 0x40)

				if xor(flag, FLAG_ENFORCE) {
					if sload(slot) {
						mstore(0x00, 0x5c426a42) // ModuleAlreadyInstalled(address)
						mstore(0x20, handler)
						revert(0x1c, 0x24)
					}
				}

				sstore(slot, or(shl(0xf8, callType), handler))
				log4(0x00, 0x00, SELECTOR_CONFIGURED_TOPIC, handler, selector, 0x01)
			}
		}
	}

	function _uninstallFallback(address handler, bytes1 flag, bytes32[] calldata configurations) internal virtual {
		assembly ("memory-safe") {
			if iszero(or(iszero(flag), eq(flag, FLAG_ENFORCE))) {
				mstore(0x00, 0x3ea063d0) // InvalidFlag()
				revert(0x1c, 0x04)
			}

			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			// prettier-ignore
			for { let i } lt(i, configurations.length) { i := add(i, 0x01) } {
				let selector := shl(0xe0, shr(0xe0, calldataload(add(configurations.offset, shl(0x05, i)))))

				mstore(0x00, selector)
				let slot := keccak256(0x00, 0x40)

				if xor(flag, FLAG_ENFORCE) {
					if iszero(sload(slot)) {
						mstore(0x00, 0xc2a825f5) // UnknownSelector(bytes4)
						mstore(0x20, selector)
						revert(0x1c, 0x24)
					}
				}

				sstore(slot, 0x00)
				log4(0x00, 0x00, SELECTOR_CONFIGURED_TOPIC, handler, selector, 0x00)
			}
		}
	}

	function _isFallbackInstalled(address handler, bytes calldata data) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shl(0xe0, shr(0xe0, calldataload(data.offset))))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			switch data.length
			case 0x04 {
				result := eq(handler, shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40)))))
			}
			case 0x05 {
				let callType := calldataload(add(data.offset, 0x04))
				let configuration := sload(keccak256(0x00, 0x40))

				result := and(
					eq(handler, shr(0x60, shl(0x60, configuration))),
					eq(callType, shl(0xf8, shr(0xf8, configuration)))
				)
			}
			default {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}
		}
	}

	function _invokeOnInstall(address module, ModuleType moduleTypeId, bytes calldata data) internal virtual {
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

	function _invokeOnUninstall(address module, ModuleType moduleTypeId, bytes calldata data) internal virtual {
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

	function _isInitialized(address module) internal view virtual returns (bool result) {
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

	function _checkModule(address module, ModuleType moduleTypeId) internal view virtual override {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, module)))
			mstore(0x20, MODULES_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))

			if iszero(shr(0x60, shl(0x60, configuration))) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, shr(0x60, shl(0x60, module)))
				revert(0x1c, 0x24)
			}

			if xor(moduleTypeId, shr(0xf8, configuration)) {
				mstore(0x00, 0x2125deae) // InvalidModuleType()
				revert(0x1c, 0x04)
			}
		}
	}

	function _checkModuleTypes(
		address module,
		ModuleType moduleTypeId,
		PackedModuleTypes packedTypes
	) internal view virtual {
		assembly ("memory-safe") {
			if iszero(extcodesize(module)) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

			if iszero(and(packedTypes, shl(moduleTypeId, 0x01))) {
				mstore(0x00, 0x2125deae) // InvalidModuleType()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xecd0596100000000000000000000000000000000000000000000000000000000) // isModuleType(uint256)

			// prettier-ignore
			for { moduleTypeId := 0x00 } lt(moduleTypeId, 0x20) { moduleTypeId := add(moduleTypeId, 0x01) } {
				if and(packedTypes, shl(moduleTypeId, 0x01)) {
					if or(iszero(moduleTypeId), gt(moduleTypeId, 0x07)) {
						mstore(0x00, 0x41c38b30) // UnsupportedModuleType(uint256)
						mstore(0x20, moduleTypeId)
						revert(0x1c, 0x24)
					}

					mstore(add(ptr, 0x04), moduleTypeId)

					if iszero(staticcall(gas(), module, ptr, 0x24, 0x00, 0x20)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					if iszero(mload(0x00)) {
						mstore(0x00, 0x2125deae) // InvalidModuleType()
						revert(0x1c, 0x04)
					}
				}
			}
		}
	}

	function _checkSelectors(
		bytes4[] memory fallbackSelectors,
		bytes4[] memory forbiddenSelectors
	) internal pure virtual {
		assembly ("memory-safe") {
			if iszero(mload(fallbackSelectors)) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			if iszero(add(fallbackSelectors, 0x20)) {
				mstore(0x00, 0x7352d91c) // InvalidSelector()
				revert(0x1c, 0x04)
			}

			let fallbackGuard := add(fallbackSelectors, shl(0x05, mload(fallbackSelectors)))
			let forbiddenGuard := add(forbiddenSelectors, shl(0x05, mload(forbiddenSelectors)))

			fallbackSelectors := add(fallbackSelectors, 0x20)
			forbiddenSelectors := add(forbiddenSelectors, 0x20)

			// prettier-ignore
			for { } iszero(or(gt(fallbackSelectors, fallbackGuard), gt(forbiddenSelectors, forbiddenGuard))) { } {
				let fallbackSelector := mload(fallbackSelectors)
				let forbiddenSelector := mload(forbiddenSelectors)

				if iszero(xor(fallbackSelector, forbiddenSelector)) {
					mstore(0x00, 0x9ff8cd94) // ForbiddenSelector(bytes4)
					mstore(0x20, shl(0xe0, shr(0xe0, fallbackSelector)))
					revert(0x1c, 0x24)
				}

				if iszero(lt(fallbackSelector, forbiddenSelector)) {
					forbiddenSelectors := add(forbiddenSelectors, 0x20)
					continue
				}

				fallbackSelectors := add(fallbackSelectors, 0x20)
			}
		}
	}

	function _processSelectors(bytes32[] memory input) internal pure virtual returns (bytes4[] memory output) {
		output = input.copy().castToBytes4s();
		output.insertionSort();
		output.uniquifySorted();
	}

	function _forbiddenSelectors() internal pure virtual returns (bytes4[] memory selectors) {
		selectors = new bytes4[](5);
		selectors[0] = 0x8dd7712f; // executeUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes),bytes32)
		selectors[1] = 0x9517e29f; // installModule(uint256,address,bytes)
		selectors[2] = 0xa71763a8; // uninstallModule(uint256,address,bytes)
		selectors[3] = 0xd691c964; // executeFromExecutor(bytes32,bytes)
		selectors[4] = 0xe9ae5c53; // execute(bytes32,bytes)
	}
}
