// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ConfigId, ModuleType, ValidationData} from "src/types/DataTypes.sol";

/// @title IModule
/// @notice ERC-7579 module base interface
interface IModule {
	/// @notice Thrown when the module has already been initialized for the given account
	error AlreadyInitialized(address account);

	/// @notice Thrown when the module has not been initialized for the given account
	error NotInitialized(address account);

	/// @notice Thrown when the provided data length is invalid
	error InvalidDataLength();

	/// @notice Installs the module with necessary initialization data
	/// @param data arbitrary data that may be required on the module during initialization
	function onInstall(bytes calldata data) external payable;

	/// @notice Uninstalls the module and allows for cleanup via arbitrary data
	/// @param data arbitrary data that may be required on the module during de-initialization
	function onUninstall(bytes calldata data) external payable;

	/// @notice Determines if the module matches a specific module type
	/// @param moduleTypeId The module type ID according the ERC-7579 spec
	/// @return True if the module is of the specified type, false otherwise
	function isModuleType(ModuleType moduleTypeId) external view returns (bool);

	/// @notice Checks if the module has been initialized for a specific smart account
	/// @param account The address of the smart account to check for initialization status
	/// @return True if the module is initialized, false otherwise
	function isInitialized(address account) external view returns (bool);
}

/// @title IValidator
/// @notice Interface for the Validator module contract
interface IValidator is IModule {
	/// @notice Validates a user operation as per ERC-4337 standard requirements
	/// @param userOp The user operation containing transaction details to be validated
	/// @param userOpHash The hash of the user operation data, used for verifying the signature
	/// @return validationData The result of the validation process, typically indicating success or the type of failure
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validationData);

	/// @notice Validates a signature against using ERC-1271
	/// @param sender The address that sent the ERC-1271 request to the smart account
	/// @param hash The hash of the ERC-1271 request
	/// @param signature The signature of the ERC-1271 request to validate
	/// @return magicValue A bytes4 value that corresponds to the ERC-1271 standard, indicating the validity of the signature
	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue);
}

/// @title IExecutor
/// @notice Interface for the Executor module contract
interface IExecutor is IModule {

}

/// @title Fallback
/// @notice Interface for the Fallback module contract
interface IFallback is IModule {

}

/// @title IHook
/// @notice Interface for the Hook module contract
interface IHook is IModule {
	/// @notice Performs checks before a transaction is executed
	/// @param msgSender The address of the original sender of the transaction
	/// @param msgValue The value that was sent with the call
	/// @param msgData The calldata of the transaction
	/// @return context The arbitrary data that may be used or modified throughout the transaction lifecycle, passed to `postCheck`
	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) external payable returns (bytes memory context);

	/// @notice Performs checks after a transaction is executed to ensure state consistency
	/// @param context The data returned from `preCheck`, containing execution context or modifications
	function postCheck(bytes calldata context) external payable;
}

/// @title IPolicy
/// @notice Interface for the Policy module contract
interface IPolicy is IModule {
	event PolicySet(ConfigId id, address multiplexer, address account);

	function initializeWithMultiplexer(address account, ConfigId configId, bytes calldata data) external;

	function isInitialized(address account, ConfigId configId) external view returns (bool);

	function isInitialized(address account, address multiplexer, ConfigId configId) external view returns (bool);
}

/// @title IUserOpPolicy
/// @notice Interface for the UserOpPolicy module contract
interface IUserOpPolicy is IPolicy {
	function checkUserOpPolicy(ConfigId id, PackedUserOperation calldata userOp) external returns (ValidationData);
}

/// @title IActionPolicy
/// @notice Interface for the ActionPolicy module contract
interface IActionPolicy is IPolicy {
	function checkAction(
		ConfigId id,
		address account,
		address target,
		uint256 value,
		bytes calldata callData
	) external returns (ValidationData);
}

/// @title I1271Policy
/// @notice Interface for the ERC1271Policy module contract
interface I1271Policy is IPolicy {
	/// @notice Enforces restrictions on 1271 signed actions
	function check1271SignedAction(
		ConfigId id,
		address requestSender,
		address account,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bool);
}

/// @title ISigner
/// @notice Interface for the Signer module contract
interface ISigner is IModule {
	function checkUserOpSignature(
		bytes32 id,
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData);

	function checkSignature(
		bytes32 id,
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4);
}

/// @title IStatelessValidator
/// @notice Interface for the StatelessValidator module contract
interface IStatelessValidator is IModule {
	/// @notice Validates a signature against using ERC-1271
	/// @param hash The hash of the data to validate
	/// @param signature The signature of the data
	/// @param data The data to validate against (owner address in this case)
	/// @return True if the signature is valid, false otherwise
	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool);
}

/// @title IPreValidationHookERC1271
/// @notice Interface for ERC-1271 pre-validation hook module contract
interface IPreValidationHookERC1271 is IModule {
	/// @notice Performs pre-validation checks for isValidSignature
	/// @dev This method is called before the validation of a signature on a validator within isValidSignature
	/// @param sender The original sender of the request
	/// @param hash The hash of signed data
	/// @param signature The signature to validate
	/// @return hookHash The hash after applying the pre-validation hook
	/// @return hookSignature The signature after applying the pre-validation hook
	function preValidationHookERC1271(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes32 hookHash, bytes memory hookSignature);
}

/// @title IPreValidationHookERC4337
/// @notice Interface for ERC-4337 pre-validation hook module contract
interface IPreValidationHookERC4337 is IModule {
	/// @notice Performs pre-validation checks for user operations
	/// @dev This method is called before the validation of a user operation
	/// @param userOp The user operation to be validated
	/// @param missingAccountFunds The amount of funds missing in the account
	/// @param userOpHash The hash of the user operation data
	/// @return hookHash The hash after applying the pre-validation hook
	/// @return hookSignature The signature after applying the pre-validation hook
	function preValidationHookERC4337(
		PackedUserOperation calldata userOp,
		uint256 missingAccountFunds,
		bytes32 userOpHash
	) external returns (bytes32 hookHash, bytes memory hookSignature);
}
