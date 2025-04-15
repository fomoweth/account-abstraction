// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {ExecutionMode, CallType, ModuleType, PackedModuleTypes, ValidationData} from "src/types/Types.sol";
import {AccessControl} from "src/core/AccessControl.sol";
import {AccountBase} from "src/core/AccountBase.sol";
import {AccountCore} from "src/core/AccountCore.sol";

/// @title Vortex Smart Account
/// @notice Modular smart account contract supporting ERC-7579 and ERC-4337 standards
contract Vortex is IVortex, AccountBase, AccountCore {
	using AccountIdLib for string;
	using CalldataDecoder for *;
	using ExecutionLib for address;

	constructor() {
		assembly ("memory-safe") {
			// prevents from initializing the implementation
			sstore(ROOT_VALIDATOR_STORAGE_SLOT, SENTINEL)
		}
	}

	/// @inheritdoc IVortex
	function initializeAccount(bytes calldata data) external payable {
		_initializeAccount(data);
	}

	/// @inheritdoc IVortex
	function execute(ExecutionMode mode, bytes calldata executionCalldata) external payable onlyEntryPoint withHook {
		_execute(mode, executionCalldata);
	}

	/// @inheritdoc IVortex
	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable onlyExecutor withHook returns (bytes[] memory returnData) {
		return _execute(mode, executionCalldata);
	}

	/// @inheritdoc IVortex
	function executeUserOp(PackedUserOperation calldata userOp, bytes32) external payable onlyEntryPoint withHook {
		bytes4 selector = userOp.callData[4:].decodeSelector();
		if (selector == this.execute.selector || selector == this.executeFromExecutor.selector) {
			(ExecutionMode mode, bytes calldata executionCalldata) = userOp.callData[8:].decodeExecutionCalldata();
			_execute(mode, executionCalldata);
		} else {
			address(this).callDelegate(userOp.callData[4:]);
		}
	}

	/// @inheritdoc IVortex
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

	/// @inheritdoc IVortex
	function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue) {
		(address validator, bytes calldata innerSignature) = _decodeSignature(signature);
		return _validateSignature(validator, hash, innerSignature);
	}

	/// @inheritdoc IVortex
	function installModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_installModule(moduleTypeId, module, data);
	}

	/// @inheritdoc IVortex
	function uninstallModule(
		ModuleType moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_uninstallModule(moduleTypeId, module, data);
	}

	/// @inheritdoc IVortex
	function isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view returns (bool installed) {
		return _isModuleInstalled(moduleTypeId, module, additionalContext);
	}

	/// @inheritdoc IVortex
	function supportsModule(ModuleType moduleTypeId) external pure returns (bool supported) {
		assembly ("memory-safe") {
			// MODULE_TYPE_VALIDATOR: 0x01
			// MODULE_TYPE_EXECUTOR: 0x02
			// MODULE_TYPE_FALLBACK: 0x03
			// MODULE_TYPE_HOOK: 0x04
			// MODULE_TYPE_POLICY: 0x05
			// MODULE_TYPE_SIGNER: 0x06
			// MODULE_TYPE_STATELESS_VALIDATOR: 0x07
			supported := and(iszero(iszero(moduleTypeId)), or(lt(moduleTypeId, 0x05), eq(moduleTypeId, 0x07)))
		}
	}

	/// @inheritdoc IVortex
	function supportsExecutionMode(ExecutionMode mode) external pure returns (bool supported) {
		assembly ("memory-safe") {
			let callType := shr(0xf8, mode)
			let execType := shr(0xf8, shl(0x08, mode))
			supported := and(
				// CALLTYPE_SINGLE: 0x00 | CALLTYPE_BATCH: 0x01 | CALLTYPE_DELEGATE: 0xFF
				or(or(eq(callType, 0x00), eq(callType, 0x01)), eq(callType, 0xFF)),
				// EXECTYPE_DEFAULT: 0x00 | EXECTYPE_TRY: 0x01
				or(eq(execType, 0x00), eq(execType, 0x01))
			)
		}
	}

	/// @notice Configures a new ERC-7484 registry
	/// @param newRegistry Address of the registry
	/// @param attesters List of trusted attesters
	/// @param threshold Minimum number of attestations required
	function configureRegistry(
		address newRegistry,
		address[] calldata attesters,
		uint8 threshold
	) external payable onlyEntryPointOrSelf {
		_configureRegistry(newRegistry, attesters, threshold);
	}

	/// @notice Configures a new root validator module
	/// @param newRootValidator Address of the validator module
	/// @param data Initialization data for the validator
	function configureRootValidator(
		address newRootValidator,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_configureRootValidator(newRootValidator, data);
	}

	/// @inheritdoc IVortex
	function accountId() public pure virtual returns (string memory) {
		return ACCOUNT_IMPLEMENTATION_ID;
	}

	/// @inheritdoc IVortex
	function entryPoint() public pure virtual returns (address) {
		return ENTRYPOINT;
	}

	/// @notice Returns the currently configured ERC-7484 registry
	/// @return Address of the ERC-7484 registry
	function registry() external view returns (address) {
		return _registry();
	}

	/// @notice Returns the currently configured root validator module
	/// @return Address of the root validator module
	function rootValidator() external view returns (address) {
		return _rootValidator();
	}

	/// @notice Returns a list of globally installed hook modules
	/// @return hooks Array of hook module addresses
	function globalHooks() external view returns (address[] memory hooks) {
		return _globalHooks();
	}

	/// @notice Retrieves the configuration for a given module
	/// @return moduleTypeId Module type identifier
	/// @return packedTypes Packed representation of sub-module types
	/// @return hook Address of the associated hook module
	function getConfiguration(
		address module
	) external view returns (ModuleType moduleTypeId, PackedModuleTypes packedTypes, address hook) {
		return _getConfiguration(module);
	}

	/// @notice Returns the fallback module configuration for a function selector
	/// @return callType Type of call that can be forwarded as
	/// @return module Address of the fallback module handling the fallback
	function fallbackHandler(bytes4 selector) external view returns (CallType callType, address module) {
		return _fallbackHandler(selector);
	}

	/// @notice Returns a list of selectors forbidden in fallback routing
	/// @return selectors Array of forbidden function selectors
	function forbiddenSelectors() external pure returns (bytes4[] memory selectors) {
		return _forbiddenSelectors();
	}

	/// @notice Returns the EIP-712 domain separator for the current chain
	/// @return The domain separator hash
	function DOMAIN_SEPARATOR() external view returns (bytes32) {
		return _domainSeparator();
	}

	/// @notice Returns the EIP-712 typed data hash for a given struct hash
	/// @param structHash The keccak256 hash of the typed struct
	/// @return The keccak256 digest of the EIP-712 typed data
	function hashTypedData(bytes32 structHash) external view returns (bytes32) {
		return _hashTypedData(structHash);
	}

	/// @notice Returns the address of the current implementation (EIP-1967)
	/// @return implementationAddress The current implementation address
	function implementation() external view returns (address) {
		return _selfImplementation();
	}

	/// @notice Upgrades the implementation and optionally executes a function call
	/// @param newImplementation Address of the new implementation
	/// @param data Calldata to execute after the upgrade
	function upgradeToAndCall(
		address newImplementation,
		bytes calldata data
	) public payable virtual override onlyProxy {
		super.upgradeToAndCall(newImplementation, data);
	}

	function _authorizeUpgrade(address newImplementation) internal virtual override onlyEntryPointOrSelf withHook {
		assembly ("memory-safe") {
			if iszero(extcodesize(newImplementation)) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}
		}
	}

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
