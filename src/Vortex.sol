// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {ExecutionMode, CallType, ModuleType, ValidationData, ValidationMode} from "src/types/DataTypes.sol";
import {AccountBase} from "src/core/AccountBase.sol";
import {AccountCore} from "src/core/AccountCore.sol";

/// @title Vortex Smart Account
/// @notice Modular smart account contract supporting ERC-7579 and ERC-4337 standards
contract Vortex is IVortex, AccountBase, AccountCore {
	using AccountIdLib for string;
	using ExecutionLib for address;

	string internal constant ACCOUNT_IMPLEMENTATION_ID = "fomoweth.vortex.1.0.0";

	constructor() {
		// prevents from initializing the implementation
		_setRootValidator(SENTINEL);
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
		bytes calldata callData = userOp.callData[4:];

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			calldatacopy(ptr, callData.offset, callData.length)

			if iszero(delegatecall(gas(), address(), ptr, callData.length, codesize(), 0x00)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0xacfdb444) // ExecutionFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @inheritdoc IVortex
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable onlyEntryPoint payPrefund(missingAccountFunds) returns (ValidationData validationData) {
		(address validator, ValidationMode mode) = _decodeUserOpNonce(userOp);

		PackedUserOperation memory op = userOp;
		if (mode == VALIDATION_MODE_ENABLE) op.signature = _enableModule(userOp.signature, userOpHash);
		(userOpHash, op.signature) = _preValidateERC4337(userOpHash, op, missingAccountFunds);

		return _validateUserOp(validator, op, userOpHash);
	}

	/// @inheritdoc IVortex
	function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue) {
		if (signature.length == 0) {
			if (uint256(hash) == (~signature.length / 0xffff) * 0x7739) {
				return _validateERC7739Support(_getValidators(), hash);
			}
		}

		(address validator, bytes memory innerSignature) = _decodeSignature(signature);
		(hash, innerSignature) = _preValidateERC1271(hash, innerSignature);
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
	function supportsModule(ModuleType moduleTypeId) public pure virtual returns (bool supported) {
		assembly ("memory-safe") {
			// MODULE_TYPE_VALIDATOR: 0x01
			// MODULE_TYPE_EXECUTOR: 0x02
			// MODULE_TYPE_FALLBACK: 0x03
			// MODULE_TYPE_HOOK: 0x04
			// MODULE_TYPE_POLICY: 0x05
			// MODULE_TYPE_SIGNER: 0x06
			// MODULE_TYPE_STATELESS_VALIDATOR: 0x07
			// MODULE_TYPE_PREVALIDATION_HOOK_ERC1271: 0x08
			// MODULE_TYPE_PREVALIDATION_HOOK_ERC4337: 0x09
			supported := xor(
				and(iszero(iszero(moduleTypeId)), iszero(gt(moduleTypeId, 0x09))),
				or(eq(moduleTypeId, 0x05), eq(moduleTypeId, 0x06))
			)
		}
	}

	/// @inheritdoc IVortex
	function supportsExecutionMode(ExecutionMode mode) public pure virtual returns (bool supported) {
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

	/// @notice Configures an ERC-7484 registry with a list of trusted attesters and a quorum threshold
	/// @param newRegistry The address of the ERC-7484 registry
	/// @param attesters The list of trusted attesters
	/// @param threshold The minimum number of attestations required
	function configureRegistry(
		address newRegistry,
		address[] calldata attesters,
		uint8 threshold
	) external payable onlyEntryPointOrSelf {
		_configureRegistry(newRegistry, attesters, threshold);
	}

	/// @notice Configures a new root validator module
	/// @param newRootValidator The address of the validator module
	/// @param data Initialization context for the validator
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

	/// @notice Returns the currently configured root validator module
	/// @return The address of the root validator module
	function rootValidator() external view returns (address) {
		return _rootValidator();
	}

	/// @notice Returns the currently configured ERC-7484 registry
	/// @return The address of the configured registry
	function registry() external view returns (address) {
		return _getRegistry();
	}

	/// @notice Returns installed validator modules
	/// @return validators The list of validator addresses
	function getValidators() external view returns (address[] memory validators) {
		return _getValidators();
	}

	/// @notice Returns installed executor modules
	/// @return executors The list of executor addresses
	function getExecutors() external view returns (address[] memory executors) {
		return _getExecutors();
	}

	/// @notice Returns globally installed hook modules
	/// @return hooks The list of globally active hook addresses
	function getGlobalHooks() external view returns (address[] memory hooks) {
		return _getHooks();
	}

	/// @notice Returns the fallback module configuration for a function selector
	/// @param selector The function selector to query
	/// @return callType The type of call redirection
	/// @return module The address of the fallback module
	function getFallbackHandler(bytes4 selector) external view returns (CallType callType, address module) {
		return _getFallbackHandler(selector);
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
	/// @return The current implementation address
	function implementation() external view returns (address) {
		return _selfImplementation();
	}

	/// @notice Upgrades the implementation and optionally executes a function call
	/// @param newImplementation The address of the new implementation
	/// @param data The calldata to execute after the upgrade
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
