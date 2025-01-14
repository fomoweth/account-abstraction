// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {ModuleLib} from "src/libraries/ModuleLib.sol";
import {ERC1271} from "src/utils/ERC1271.sol";
import {CallType} from "src/types/ExecutionMode.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title AccountModule

abstract contract AccountModule is ERC1271, RegistryAdapter {
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;
	using ModuleLib for address;

	/// @dev keccak256(bytes("ModuleEnableMode(address module,uint256 moduleType,bytes32 userOpHash,bytes32 initDataHash)"));
	bytes32 private constant MODULE_ENABLE_MODE_TYPE_HASH =
		0xbe844ccefa05559a48680cb7fe805b2ec58df122784191aed18f9f315c763e1b;

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

	function getFallbackHandler(bytes4 selector) public view returns (CallType callType, address handler) {
		return ModuleLib.getFallbackHandler(selector);
	}

	function getActiveHook() external view returns (address hook) {
		return ModuleLib.getHook();
	}

	function _initializeModules() internal virtual {
		ModuleLib.getValidatorsList().initialize();
		ModuleLib.getExecutorsList().initialize();
	}

	function _enableMode(
		bytes32 userOpHash,
		bytes calldata data
	) internal virtual withHook returns (bytes calldata userOpSignature) {
		address module;
		uint256 moduleTypeId;
		bytes calldata initData;
		bytes calldata signature;
		(module, moduleTypeId, initData, signature, userOpSignature) = data.decodeEnableModeData();
		_checkEnableModeSignature(_buildEnableModeHash(module, moduleTypeId, userOpHash, initData), signature);

		_installModule(moduleTypeId, module, initData);
	}

	function _installModule(uint256 moduleTypeId, address module, bytes calldata data) internal virtual {
		if (moduleTypeId == ModuleLib.MODULE_TYPE_MULTI) {
			module.installMultiType(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_VALIDATOR) {
			module.installValidator(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_EXECUTOR) {
			module.installExecutor(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_FALLBACK) {
			module.installFallbackHandler(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_HOOK) {
			module.installHook(data);
		} else {
			ModuleLib.InvalidModuleTypeId.selector.revertWith(moduleTypeId);
		}
	}

	function _uninstallModule(uint256 moduleTypeId, address module, bytes calldata data) internal virtual {
		if (moduleTypeId == ModuleLib.MODULE_TYPE_VALIDATOR) {
			module.uninstallValidator(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_EXECUTOR) {
			module.uninstallExecutor(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_FALLBACK) {
			module.uninstallFallbackHandler(data);
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_HOOK) {
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
		if (moduleTypeId == ModuleLib.MODULE_TYPE_VALIDATOR) {
			return module.isValidatorInstalled();
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_EXECUTOR) {
			return module.isExecutorInstalled();
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_FALLBACK) {
			return module.isFallbackHandlerInstalled(additionalContext.decodeSelector());
		} else if (moduleTypeId == ModuleLib.MODULE_TYPE_HOOK) {
			return module.isHookInstalled();
		}

		return false;
	}

	function _hasValidators() internal view virtual returns (bool) {
		return !ModuleLib.getValidatorsList().isEmpty();
	}

	function _checkEnableModeSignature(bytes32 structHash, bytes calldata signature) internal view {
		address validator = signature.decodeAddress();
		if (!validator.isValidatorInstalled()) ModuleLib.InvalidModule.selector.revertWith(validator);

		bytes32 eip712Digest = _hashTypedData(structHash);

		assembly ("memory-safe") {
			signature.offset := add(signature.offset, 0x14)
			signature.length := sub(signature.length, 0x14)

			let ptr := mload(0x40)

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), eip712Digest)
			calldatacopy(add(ptr, 0x44), signature.offset, signature.length)

			if iszero(
				and(
					eq(mload(0x00), EIP1271_SUCCESS),
					staticcall(gas(), validator, ptr, add(signature.length, 0x44), 0x00, 0x20)
				)
			) {
				mstore(0x00, 0x82b3d6e5) // InvalidEnableModeSignature()
				revert(0x1c, 0x04)
			}
		}
	}

	function _buildEnableModeHash(
		address module,
		uint256 moduleTypeId,
		bytes32 userOpHash,
		bytes calldata data
	) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(0x40, add(add(ptr, 0x80), data.length))

			mstore(ptr, MODULE_ENABLE_MODE_TYPE_HASH)
			mstore(add(ptr, 0x20), and(module, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x40), moduleTypeId)
			mstore(add(ptr, 0x60), userOpHash)
			calldatacopy(add(ptr, 0x80), data.offset, data.length)
			mstore(add(ptr, 0x80), keccak256(add(ptr, 0x80), data.length))

			digest := keccak256(ptr, 0xa0)
		}
	}
}
