// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ModuleType, ValidationData} from "src/types/Types.sol";

interface IModule {
	error AlreadyInitialized(address account);
	error NotInitialized(address account);

	/**
	 * @notice This function is called by the smart account during installation of the module
	 * @param data arbitrary data that may be required on the module during `onInstall`
	 * initialization
	 *
	 * MUST revert on error (i.e. if module is already enabled)
	 */
	function onInstall(bytes calldata data) external payable;

	/**
	 * @notice This function is called by the smart account during uninstallation of the module
	 * @param data arbitrary data that may be required on the module during `onUninstall`
	 * de-initialization
	 *
	 * MUST revert on error
	 */
	function onUninstall(bytes calldata data) external payable;

	/**
	 * @notice Returns boolean value if module is a certain type
	 * @param moduleTypeId the module type ID according the ERC-7579 spec
	 *
	 * MUST return true if the module is of the given type and false otherwise
	 */
	function isModuleType(ModuleType moduleTypeId) external view returns (bool);

	/**
	 * @notice Returns if the module was already initialized for a provided smart account
	 */
	function isInitialized(address account) external view returns (bool);
}

interface IValidator is IModule {
	/**
	 * @notice Validates a UserOperation
	 * @param userOp the ERC-4337 PackedUserOperation
	 * @param userOpHash the hash of the ERC-4337 PackedUserOperation
	 *
	 * MUST validate that the signature is a valid signature of the userOpHash
	 * SHOULD return ERC-4337's SIG_VALIDATION_FAILED (and not revert) on signature mismatch
	 */
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData);

	/**
	 * @notice Validates a signature using ERC-1271
	 * @param sender the address that sent the ERC-1271 request to the smart account
	 * @param hash the hash of the ERC-1271 request
	 * @param signature the signature of the ERC-1271 request
	 *
	 * MUST return the ERC-1271 `MAGIC_VALUE` if the signature is valid
	 * MUST NOT modify state
	 */
	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4);
}

interface IExecutor is IModule {}

interface IFallback is IModule {}

interface IHook is IModule {
	/**
	 * @notice Called by the smart account before execution
	 * @param msgSender the address that called the smart account
	 * @param msgValue the value that was sent to the smart account
	 * @param msgData the data that was sent to the smart account
	 *
	 * MAY return arbitrary data in the `hookData` return value
	 */
	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) external payable returns (bytes memory hookData);

	/**
	 * @notice Called by the smart account after execution
	 * @param hookData the data that was returned by the `preCheck` function
	 *
	 * MAY validate the `hookData` to validate transaction context of the `preCheck` function
	 */
	function postCheck(bytes calldata hookData) external payable;
}

interface IPolicy is IModule {
	function checkUserOpPolicy(bytes32 id, PackedUserOperation calldata userOp) external payable returns (uint256);

	function checkSignaturePolicy(
		bytes32 id,
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (uint256);
}

interface ISigner is IModule {
	function checkUserOpSignature(
		bytes32 id,
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (uint256);

	function checkSignature(
		bytes32 id,
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4);
}

interface IStatelessValidator is IModule {
	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool);
}
