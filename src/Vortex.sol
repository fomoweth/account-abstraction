// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {Errors} from "src/libraries/Errors.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {CALLTYPE_DELEGATE, EXECTYPE_DEFAULT} from "src/types/Constants.sol";
import {ExecutionMode, CallType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";
import {EIP712} from "src/utils/EIP712.sol";
import {UUPSUpgradeable} from "src/utils/UUPSUpgradeable.sol";
import {Account} from "src/core/Account.sol";

/// @title Vortex

contract Vortex is IVortex, Account, EIP712, UUPSUpgradeable {
	using AccountIdLib for string;
	using ExecutionLib for bytes;

	function initializeAccount(bytes calldata data) external payable virtual {
		require(_rootValidator() == ZERO, Errors.InvalidInitialization());
		data.executeDelegate(EXECTYPE_DEFAULT);
		require(_rootValidator() != ZERO, Errors.InvalidInitialization());
	}

	function execute(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable virtual onlyEntryPoint withHook {
		_execute(mode, executionCalldata);
	}

	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable virtual onlyExecutor withHook returns (bytes[] memory results) {
		return _execute(mode, executionCalldata);
	}

	function executeUserOp(
		PackedUserOperation calldata userOp,
		bytes32
	) external payable virtual onlyEntryPoint withHook {
		_execute(CALLTYPE_DELEGATE, address(this), 0, userOp.callData[4:]);
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable virtual onlyEntryPoint payPrefund(missingAccountFunds) returns (uint256 validationData) {
		return _validateUserOp(_parseValidator(userOp.nonce), userOp, userOpHash);
	}

	function isValidSignature(
		bytes32 hash,
		bytes calldata signature
	) external view virtual returns (bytes4 magicValue) {
		(address validator, bytes calldata innerSignature) = _decodeSignature(signature);

		return _isValidSignature(validator, hash, innerSignature);
	}

	function installModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable virtual onlyEntryPointOrSelf withHook withRegistry(module, moduleTypeId) {
		_installModule(moduleTypeId, module, data);
	}

	function uninstallModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable virtual onlyEntryPointOrSelf withHook {
		_uninstallModule(moduleTypeId, module, data);
	}

	function isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view virtual returns (bool) {
		return _isModuleInstalled(moduleTypeId, module, additionalContext);
	}

	function supportsModule(ModuleType moduleTypeId) public pure virtual returns (bool result) {
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

	function supportsExecutionMode(ExecutionMode mode) public pure virtual returns (bool result) {
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

	function configureRootValidator(
		address newValidator,
		bytes calldata data
	) external payable virtual onlyEntryPointOrSelf {
		_configureRootValidator(newValidator, data);
	}

	function configureRegistry(
		address newRegistry,
		address[] calldata attesters,
		uint8 threshold
	) external payable virtual onlyEntryPointOrSelf {
		_configureRegistry(newRegistry, attesters, threshold);
	}

	function rootValidator() external view virtual returns (address) {
		return _rootValidator();
	}

	function registry() external view virtual returns (address) {
		return _registry();
	}

	function hook() external view virtual returns (address) {
		return _hook(ENTRYPOINT);
	}

	function getConfiguration(address module) external view virtual returns (ModuleType, PackedModuleTypes, address) {
		return _getConfiguration(module);
	}

	function fallbackHandler(bytes4 selector) external view virtual returns (CallType, address) {
		return _fallbackHandler(selector);
	}

	function accountId() public pure virtual returns (string memory) {
		return "fomoweth.vortex.1.0.0";
	}

	function _authorizeUpgrade(address newImplementation) internal virtual override onlyEntryPointOrSelf withHook {}

	function _domainNameAndVersion()
		internal
		view
		virtual
		override
		returns (string memory name, string memory version)
	{
		return accountId().parse();
	}

	fallback() external payable virtual {
		_fallback();
	}

	receive() external payable virtual {}
}
