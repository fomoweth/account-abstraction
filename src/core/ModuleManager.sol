// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {Calldata} from "src/libraries/Calldata.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CallType, ModuleType} from "src/types/DataTypes.sol";
import {AccessControl} from "./AccessControl.sol";
import {ERC7201} from "./ERC7201.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title ModuleManager
/// @notice Base contract that manages the modules enabled on a smart account.
abstract contract ModuleManager is AccessControl, ERC7201, RegistryAdapter {
	using CalldataDecoder for bytes;
	using EnumerableSetLib for EnumerableSetLib.AddressSet;

	error ModuleAlreadyInstalled(ModuleType moduleTypeId, address module);

	error ModuleNotInstalled(ModuleType moduleTypeId, address module);

	error UnsupportedPreValidationHookType(ModuleType moduleTypeId);

	error InvalidRootValidator();

	error RootValidatorCannotBeRemoved();

	event RootValidatorConfigured(address indexed rootValidator);

	/// @dev keccak256("ModuleInstalled(uint256,address)")
	bytes32 private constant MODULE_INSTALLED_TOPIC =
		0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123;

	/// @dev keccak256("ModuleUninstalled(uint256,address)")
	bytes32 private constant MODULE_UNINSTALLED_TOPIC =
		0x341347516a9de374859dfda710fa4828b2d48cb57d4fbe4c1149612b8e02276e;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.vortex.storage.fallbacks")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant FALLBACKS_STORAGE_SLOT =
		0x6aa9b80a3ef8fd7c61052fd742393c4cad924e6f735976eb39535648c67cd200;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.vortex.storage.hooks")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant HOOKS_STORAGE_SLOT = 0x804aa2c00aa2afd5774b5603b005ba2fe99b98231bb0faa297c8cbc51d78c800;

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;

	ModuleType internal constant MODULE_TYPE_MULTI = ModuleType.wrap(0x00);
	ModuleType internal constant MODULE_TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant MODULE_TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant MODULE_TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant MODULE_TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant MODULE_TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant MODULE_TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant MODULE_TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);
	ModuleType internal constant MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 = ModuleType.wrap(0x08);
	ModuleType internal constant MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 = ModuleType.wrap(0x09);

	function _configureRootValidator(address rootValidator, bytes calldata data) internal virtual {
		AccountStorage storage state = _getAccountStorage();
		if (rootValidator == address(0) || rootValidator == state.rootValidator) revert InvalidRootValidator();

		if (!state.validators.contains(rootValidator)) _installModule(MODULE_TYPE_VALIDATOR, rootValidator, data);
		else if (!_isInitialized(rootValidator)) _invokeOnInstall(rootValidator, data);

		_setRootValidator(rootValidator);
	}

	function _setRootValidator(address module) internal virtual {
		emit RootValidatorConfigured(_getAccountStorage().rootValidator = module);
	}

	function _rootValidator() internal view virtual returns (address rootValidator) {
		return _getAccountStorage().rootValidator;
	}

	function _installModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) internal virtual withRegistry(module, moduleTypeId) {
		_validateModuleType(moduleTypeId, module);

		address hook;
		bytes calldata hookData;
		(data, hook, hookData) = data.decodeInstallModuleParams();

		AccountStorage storage state = _getAccountStorage();

		if (moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR) {
			require(state.validators.add(module), ModuleAlreadyInstalled(MODULE_TYPE_VALIDATOR, module));
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			require(state.executors.add(module), ModuleAlreadyInstalled(MODULE_TYPE_EXECUTOR, module));
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes32[] calldata selectors;
			(selectors, data) = data.decodeFallbackParams();

			_installFallback(module, selectors);
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			require(state.hooks.add(module), ModuleAlreadyInstalled(MODULE_TYPE_HOOK, module));
		} else if (
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 ||
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC4337
		) {
			_installPreValidationHook(moduleTypeId, module);
		}

		assembly ("memory-safe") {
			// Store the hook address for the given module, defaulting to the SENTINEL: address(1).
			module := shr(0x60, shl(0x60, module))
			mstore(0x00, module)
			mstore(0x20, HOOKS_STORAGE_SLOT)
			sstore(keccak256(0x00, 0x40), shr(0x60, shl(0x60, hook)))

			let ptr := mload(0x40)
			mstore(ptr, moduleTypeId)
			mstore(add(ptr, 0x20), module)
			log1(ptr, 0x40, MODULE_INSTALLED_TOPIC)
		}

		if (!_isInitialized(module)) _invokeOnInstall(module, data);
		if (hook != SENTINEL && !_isInitialized(hook)) _invokeOnInstall(hook, hookData);
	}

	function _uninstallModule(ModuleType moduleTypeId, address module, bytes calldata data) internal virtual {
		_validateModuleType(moduleTypeId, module);

		address hook;
		bytes calldata hookData;
		(data, hookData) = data.decodeUninstallModuleParams();

		AccountStorage storage state = _getAccountStorage();

		if (moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR) {
			require(state.rootValidator != module, RootValidatorCannotBeRemoved());
			require(state.validators.remove(module), ModuleNotInstalled(MODULE_TYPE_VALIDATOR, module));
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			require(state.executors.remove(module), ModuleNotInstalled(MODULE_TYPE_EXECUTOR, module));
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			bytes32[] calldata selectors;
			(selectors, data) = data.decodeFallbackParams();

			_uninstallFallback(module, selectors);
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			require(state.hooks.remove(module), ModuleNotInstalled(MODULE_TYPE_HOOK, module));
		} else if (
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 ||
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC4337
		) {
			_setPreValidationHook(moduleTypeId, module);
		}

		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))
			mstore(0x00, module)
			mstore(0x20, HOOKS_STORAGE_SLOT)

			// Retrieve the hook address for the given module and clear its storage slot.
			let slot := keccak256(0x00, 0x40)
			hook := shr(0x60, shl(0x60, sload(slot)))
			sstore(slot, 0x00)

			let ptr := mload(0x40)
			mstore(ptr, moduleTypeId)
			mstore(add(ptr, 0x20), module)
			log1(ptr, 0x40, MODULE_UNINSTALLED_TOPIC)
		}

		if (_isInitialized(module)) _invokeOnUninstall(module, data);
		if (hook != SENTINEL && _isInitialized(hook)) _invokeOnUninstall(hook, hookData);
	}

	function _isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) internal view virtual returns (bool installed) {
		if (moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR) {
			return _getAccountStorage().validators.contains(module);
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			return _getAccountStorage().executors.contains(module);
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			return _isFallbackInstalled(module, additionalContext);
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			return _getAccountStorage().hooks.contains(module);
		} else if (
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 ||
			moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC4337
		) {
			return _getPreValidationHook(moduleTypeId) == module;
		} else {
			return false;
		}
	}

	function _installFallback(address module, bytes32[] calldata selectors) internal virtual {
		assembly ("memory-safe") {
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let configuration
			let callType
			let selector
			let slot

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
				configuration := calldataload(add(selectors.offset, shl(0x05, i)))
				callType := shr(0xf8, shl(0x20, configuration))
				selector := shr(0xe0, configuration)

				// Ensure the current call type is not one of the following restricted values:
				// - CALLTYPE_SINGLE: 0x00
				// - CALLTYPE_STATIC: 0xFE
				// - CALLTYPE_DELEGATE: 0xFF
				if iszero(or(iszero(callType), or(eq(callType, 0xFE), eq(callType, 0xFF)))) {
					mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
					mstore(0x20, shl(0xf8, callType))
					revert(0x1c, 0x24)
				}

				// Ensure the current selector is not one of the following restricted values:
				// - bytes4(0)
				// - 0x6d61fe70: onInstall(bytes)
				// - 0x8a91b0e3: onUninstall(bytes)
				if or(iszero(selector), or(eq(selector, 0x6d61fe70), eq(selector, 0x8a91b0e3))) {
					mstore(0x00, 0x9ff8cd94) // ForbiddenSelector(bytes4)
					mstore(0x20, shl(0xe0, selector))
					revert(0x1c, 0x24)
				}

				mstore(0x00, shl(0xe0, selector))
				slot := keccak256(0x00, 0x40)

				if sload(slot) {
					mstore(0x00, 0x172c3c6a) // ModuleAlreadyInstalled(uint256,address)
					mstore(0x20, 0x03)
					mstore(0x40, module)
					revert(0x1c, 0x44)
				}

				sstore(slot, or(shl(0xf8, callType), module))
			}
		}
	}

	function _uninstallFallback(address module, bytes32[] calldata selectors) internal virtual {
		assembly ("memory-safe") {
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let selector
			let slot

			// prettier-ignore
			for { let i } lt(i, selectors.length) { i := add(i, 0x01) } {
				selector := shr(0xe0, calldataload(add(selectors.offset, shl(0x05, i))))

				// Ensure the current selector is not one of the following restricted values:
				// - bytes4(0)
				// - 0x6d61fe70: onInstall(bytes)
				// - 0x8a91b0e3: onUninstall(bytes)
				if or(iszero(selector), or(eq(selector, 0x6d61fe70), eq(selector, 0x8a91b0e3))) {
					mstore(0x00, 0x9ff8cd94) // ForbiddenSelector(bytes4)
					mstore(0x20, shl(0xe0, selector))
					revert(0x1c, 0x24)
				}

				mstore(0x00, shl(0xe0, selector))
				slot := keccak256(0x00, 0x40)

				if iszero(sload(slot)) {
					mstore(0x00, 0xbe601672) // ModuleNotInstalled(uint256,address)
					mstore(0x20, 0x03)
					mstore(0x40, module)
					revert(0x1c, 0x44)
				}

				sstore(slot, 0x00)
			}
		}
	}

	function _isFallbackInstalled(address module, bytes calldata data) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			mstore(0x00, shl(0xe0, shr(0xe0, calldataload(data.offset))))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)
			result := eq(module, shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40)))))
		}
	}

	function _getFallbackHandler(bytes4 selector) internal view virtual returns (CallType callType, address module) {
		assembly ("memory-safe") {
			mstore(0x00, shl(0xe0, shr(0xe0, selector)))
			mstore(0x20, FALLBACKS_STORAGE_SLOT)

			let configuration := sload(keccak256(0x00, 0x40))
			if configuration {
				callType := shl(0xf8, shr(0xf8, configuration))
				module := shr(0x60, shl(0x60, configuration))
			}
		}
	}

	function _installPreValidationHook(ModuleType moduleTypeId, address module) internal virtual {
		require(_getPreValidationHook(moduleTypeId) == address(0), ModuleAlreadyInstalled(moduleTypeId, module));
		_setPreValidationHook(moduleTypeId, module);
	}

	function _setPreValidationHook(ModuleType moduleTypeId, address module) internal virtual {
		_validatePreValidationHookType(moduleTypeId);
		_getAccountStorage().preValidationHooks[moduleTypeId] = module;
	}

	function _getPreValidationHook(ModuleType moduleTypeId) internal view virtual returns (address preValidationHook) {
		return _getAccountStorage().preValidationHooks[moduleTypeId];
	}

	function _getValidators() internal view virtual returns (address[] memory validators) {
		return _getAccountStorage().validators.values();
	}

	function _getExecutors() internal view virtual returns (address[] memory executors) {
		return _getAccountStorage().executors.values();
	}

	function _getHooks() internal view virtual returns (address[] memory hooks) {
		return _getAccountStorage().hooks.values();
	}

	function _getHook(address module) internal view virtual returns (address hook) {
		assembly ("memory-safe") {
			module := shr(0x60, shl(0x60, module))
			mstore(0x00, module)
			mstore(0x20, HOOKS_STORAGE_SLOT)

			hook := shr(0x60, shl(0x60, sload(keccak256(0x00, 0x40))))

			// The default state for a module-specific hook is set to SENTINEL: address(1)
			// to indicate that no hook has been installed yet.
			// Therefore, it will be reverted if the hook address is zero.
			if iszero(hook) {
				mstore(0x00, 0x026d9639) // ModuleNotInstalled(address)
				mstore(0x20, module)
				revert(0x1c, 0x24)
			}
		}
	}

	function _invokeOnInstall(address module, bytes calldata data) internal virtual {
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

	function _invokeOnUninstall(address module, bytes calldata data) internal virtual {
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

	function _validateModuleType(ModuleType moduleTypeId, address module) internal view virtual {
		assembly ("memory-safe") {
			if or(
				or(iszero(moduleTypeId), gt(moduleTypeId, 0x09)),
				or(eq(moduleTypeId, 0x05), eq(moduleTypeId, 0x06))
			) {
				mstore(0x00, 0x41c38b30) // UnsupportedModuleType(uint256)
				mstore(0x20, moduleTypeId)
				revert(0x1c, 0x24)
			}

			if iszero(shl(0x60, module)) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xecd0596100000000000000000000000000000000000000000000000000000000) // isModuleType(uint256)
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

	function _validatePreValidationHookType(ModuleType moduleTypeId) internal pure virtual {
		assembly ("memory-safe") {
			if iszero(or(eq(moduleTypeId, 0x08), eq(moduleTypeId, 0x09))) {
				mstore(0x00, 0xa86ebca7) // UnsupportedPreValidationHookType(uint256)
				mstore(0x20, moduleTypeId)
				revert(0x1c, 0x24)
			}
		}
	}
}
