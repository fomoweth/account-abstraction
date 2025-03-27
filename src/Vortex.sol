// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {VALIDATION_MODE_ENABLE} from "src/types/Constants.sol";
import {ExecutionMode, CallType, ModuleType, PackedModuleTypes, ValidationData, ValidationMode} from "src/types/Types.sol";
import {AccountCore} from "src/core/AccountCore.sol";

/// @title Vortex

contract Vortex is IVortex, AccountCore {
	using AccountIdLib for string;

	constructor() {
		// prevents from initializing the implementation
		assembly ("memory-safe") {
			sstore(ROOT_VALIDATOR_STORAGE_SLOT, SENTINEL)
		}
	}

	function initializeAccount(bytes calldata data) external payable {
		_initializeAccount(data);
	}

	function execute(ExecutionMode mode, bytes calldata executionCalldata) external payable onlyEntryPoint withHook {
		_execute(mode, executionCalldata);
	}

	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable onlyExecutor withHook returns (bytes[] memory returnData) {
		return _execute(mode, executionCalldata);
	}

	function executeUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable onlyEntryPoint withHook {
		_executeUserOp(userOp, userOpHash);
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable onlyEntryPoint payPrefund(missingAccountFunds) returns (ValidationData validationData) {
		(address validator, bool isEnableMode) = _decodeUserOpNonce(userOp);

		if (isEnableMode) {
			PackedUserOperation memory op = userOp;
			op.signature = _enableModule(userOp.signature, userOpHash);
			return _validateUserOp(validator, op, userOpHash);
		} else {
			return _validateUserOp(validator, userOp, userOpHash);
		}
	}

	function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue) {
		(address validator, bytes calldata innerSignature) = _decodeSignature(signature);
		return _validateSignature(validator, hash, innerSignature);
	}

	function installModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_installModule(moduleTypeId, module, data);
	}

	function uninstallModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_uninstallModule(moduleTypeId, module, data);
	}

	function isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view returns (bool result) {
		return _isModuleInstalled(moduleTypeId, module, additionalContext);
	}

	function supportsModule(ModuleType moduleTypeId) external pure returns (bool result) {
		assembly ("memory-safe") {
			// MODULE_TYPE_VALIDATOR: 0x01
			// MODULE_TYPE_EXECUTOR: 0x02
			// MODULE_TYPE_FALLBACK: 0x03
			// MODULE_TYPE_HOOK: 0x04
			// MODULE_TYPE_POLICY: 0x05
			// MODULE_TYPE_SIGNER: 0x06
			// MODULE_TYPE_STATELESS_VALIDATOR: 0x07
			result := and(iszero(iszero(moduleTypeId)), or(lt(moduleTypeId, 0x05), eq(moduleTypeId, 0x07)))
		}
	}

	function supportsExecutionMode(ExecutionMode mode) external pure returns (bool result) {
		assembly ("memory-safe") {
			let callType := shr(0xf8, mode)
			let execType := shr(0xf8, shl(0x08, mode))
			result := and(
				// CALLTYPE_SINGLE: 0x00 | CALLTYPE_BATCH: 0x01 | CALLTYPE_DELEGATE: 0xFF
				or(or(eq(callType, 0x00), eq(callType, 0x01)), eq(callType, 0xFF)),
				// EXECTYPE_DEFAULT: 0x00 | EXECTYPE_TRY: 0x01
				or(eq(execType, 0x00), eq(execType, 0x01))
			)
		}
	}

	function configureRegistry(
		address newRegistry,
		address[] calldata attesters,
		uint8 threshold
	) external payable onlyEntryPointOrSelf {
		_configureRegistry(newRegistry, attesters, threshold);
	}

	function configureRootValidator(
		address newRootValidator,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_configureRootValidator(newRootValidator, data);
	}

	function entryPoint() external pure returns (address) {
		return ENTRYPOINT;
	}

	function accountId() external pure returns (string memory) {
		return ACCOUNT_IMPLEMENTATION_ID;
	}

	function registry() external view returns (address) {
		return _registry();
	}

	function rootValidator() external view returns (address) {
		return _rootValidator();
	}

	function globalHooks() external view returns (address[] memory hooks) {
		return _globalHooks();
	}

	function getConfiguration(
		address module
	) external view returns (ModuleType moduleTypeId, PackedModuleTypes packedTypes, address hook) {
		return _getConfiguration(module);
	}

	function fallbackHandler(bytes4 selector) external view returns (CallType callType, address module) {
		return _fallbackHandler(selector);
	}

	function forbiddenSelectors() external pure returns (bytes4[] memory selectors) {
		return _forbiddenSelectors();
	}

	function _authorizeUpgrade(address newImplementation) internal virtual override onlyEntryPointOrSelf withHook {}

	function _domainNameAndVersion()
		internal
		view
		virtual
		override
		returns (string memory name, string memory version)
	{
		return ACCOUNT_IMPLEMENTATION_ID.parse();
	}

	fallback() external payable virtual {
		_fallback();
	}

	receive() external payable virtual {}
}
