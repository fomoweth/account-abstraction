// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ModuleType, ValidationData} from "src/types/Types.sol";

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
	/// @param account Address of the smart account to check for initialization status
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
	/// @return hookData The arbitrary data that may be used or modified throughout the transaction lifecycle, passed to `postCheck`
	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) external payable returns (bytes memory hookData);

	/// @notice Performs checks after a transaction is executed to ensure state consistency
	/// @param hookData The data returned from `preCheck`, containing execution context or modifications
	function postCheck(bytes calldata hookData) external payable;
}

/// @title IPolicy
/// @notice Interface for the Policy module contract
interface IPolicy is IModule {
	function checkUserOpPolicy(
		bytes32 id,
		PackedUserOperation calldata userOp
	) external payable returns (ValidationData);

	function checkSignaturePolicy(
		bytes32 id,
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (ValidationData);
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
	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool);
}
