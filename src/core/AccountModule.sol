// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {ModuleLib} from "src/libraries/ModuleLib.sol";
import {CallType} from "src/types/ExecutionMode.sol";

/// @title AccountModule

abstract contract AccountModule {
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;
	using ModuleLib for address;

	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;
	uint256 internal constant MODULE_TYPE_POLICY = 5;
	uint256 internal constant MODULE_TYPE_SIGNER = 6;
	uint256 internal constant MODULE_TYPE_STATELESS_VALIDATOR = 7;

	modifier initializeModules() {
		_initializeModules();
		_;
		if (!_hasValidators()) ModuleLib.NoValidatorInstalled.selector.revertWith();
	}

	modifier onlyExecutorModule() {
		if (!msg.sender.isExecutorInstalled()) ModuleLib.InvalidModule.selector.revertWith(msg.sender);
		_;
	}

	modifier onlyValidatorModule(address validator) {
		if (!validator.isValidatorInstalled()) ModuleLib.InvalidModule.selector.revertWith(validator);
		_;
	}

	modifier withHook() {
		address hook = ModuleLib.getHook();
		if (hook == address(0)) {
			_;
		} else {
			bytes memory hookData = IHook(hook).preCheck(msg.sender, msg.value, msg.data);
			_;
			IHook(hook).postCheck(hookData);
		}
	}

	function getValidatorsPaginated(
		address cursor,
		uint256 size
	) external view returns (address[] memory validators, address nextCursor) {
		return ModuleLib.getValidatorsList().paginate(cursor, size);
	}

	function getExecutorsPaginated(
		address cursor,
		uint256 size
	) external view returns (address[] memory executors, address nextCursor) {
		return ModuleLib.getExecutorsList().paginate(cursor, size);
	}

	function getFallback(bytes4 selector) public view returns (CallType callType, address handler) {
		return ModuleLib.getFallback(selector);
	}

	function getActiveHook() external view returns (address hook) {
		return ModuleLib.getHook();
	}

	function _initializeModules() internal virtual {
		ModuleLib.getValidatorsList().initialize();
		ModuleLib.getExecutorsList().initialize();
	}

	function _installModule(uint256 moduleTypeId, address module, bytes calldata data) internal virtual {
		if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
			module.installValidator(data);
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			module.installExecutor(data);
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			module.installFallback(data);
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			module.installHook(data);
		} else {
			ModuleLib.InvalidModuleTypeId.selector.revertWith(moduleTypeId);
		}
	}

	function _uninstallModule(uint256 moduleTypeId, address module, bytes calldata data) internal virtual {
		if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
			module.uninstallValidator(data);
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			module.uninstallExecutor(data);
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			module.uninstallFallback(data);
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			module.uninstallHook(data);
		} else {
			ModuleLib.InvalidModuleTypeId.selector.revertWith(moduleTypeId);
		}
	}

	function _isModuleInstalled(
		uint256 moduleTypeId,
		address module,
		bytes calldata additionalContext
	) internal view virtual returns (bool) {
		if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
			return module.isValidatorInstalled();
		} else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
			return module.isExecutorInstalled();
		} else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			return module.isFallbackInstalled(additionalContext.decodeSelector());
		} else if (moduleTypeId == MODULE_TYPE_HOOK) {
			return module.isHookInstalled();
		}

		return false;
	}

	function _hasValidators() internal view virtual returns (bool) {
		return !ModuleLib.getValidatorsList().isEmpty();
	}

	function _checkModuleTypeSupport(uint256 moduleTypeId) internal pure virtual {
		assembly ("memory-safe") {
			// MODULE_TYPE_VALIDATOR: 0x01
			// MODULE_TYPE_EXECUTOR: 0x02
			// MODULE_TYPE_FALLBACK: 0x03
			// MODULE_TYPE_HOOK: 0x04
			// MODULE_TYPE_POLICY: 0x05
			// MODULE_TYPE_SIGNER: 0x06
			// MODULE_TYPE_STATELESS_VALIDATOR: 0x07
			if or(iszero(moduleTypeId), gt(moduleTypeId, MODULE_TYPE_HOOK)) {
				mstore(0x00, 0x41c38b30) // UnsupportedModuleType(uint256)
				mstore(0x20, moduleTypeId)
				revert(0x1c, 0x24)
			}
		}
	}
}
