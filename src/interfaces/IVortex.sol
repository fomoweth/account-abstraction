// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecutionMode, ModuleType, PackedModuleTypes, ValidationData} from "src/types/Types.sol";

/// @title IVortex
/// @notice Interface for the Vortex contract
interface IVortex {
	/// @notice Emitted when a module is installed onto a smart account
	/// @param moduleTypeId The identifier for the type of module installed
	/// @param module The address of the installed module
	event ModuleInstalled(ModuleType moduleTypeId, address module);

	/// @notice Emitted when a module is uninstalled from a smart account
	/// @param moduleTypeId The identifier for the type of module uninstalled
	/// @param module The address of the uninstalled module
	event ModuleUninstalled(ModuleType moduleTypeId, address module);

	/// @notice Initializes the smart account with the provided configuration data
	/// @param data Encoded initialization context
	function initializeAccount(bytes calldata data) external payable;

	/// @notice Executes a transaction in a specified execution mode
	/// @param mode The execution mode, defining how the transaction is processed
	/// @param executionCalldata Encoded calldata for the execution
	function execute(ExecutionMode mode, bytes calldata executionCalldata) external payable;

	/// @notice Executes a transaction via an executor module
	/// @param mode The execution mode, defining how the transaction is processed
	/// @param executionCalldata Encoded calldata for the execution
	/// @return returnData The list of return values, including errors if using try mode
	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable returns (bytes[] memory returnData);

	/// @notice Executes a user operation as defined in ERC-4337
	/// @param userOp The user operation structure
	/// @param userOpHash Hash of the user operation
	function executeUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external payable;

	/// @notice Validates a user operation using a validator derived from the nonce
	/// @param userOp The user operation structure
	/// @param userOpHash Hash of the operation
	/// @param missingAccountFunds The amount required to fund the operation via EntryPoint
	/// @return validationData The result of the validation process returned by the validator module
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable returns (ValidationData validationData);

	/// @notice Validates a signature according to ERC-1271
	/// @param hash The message hash that was signed
	/// @param signature The signature to validate
	/// @return magicValue ERC-1271 magic value (`0x1626ba7e`) if valid
	function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);

	/// @notice Installs a module of a specific type
	/// @param moduleTypeId The identifier for the module type
	/// @param module The address of the module
	/// @param data Initialization context for the module
	function installModule(ModuleType moduleTypeId, address module, bytes calldata data) external payable;

	/// @notice Uninstalls a module of a specific type
	/// @param moduleTypeId The identifier for the module type
	/// @param module The address of the module
	/// @param data Deinitialization context for the module
	function uninstallModule(ModuleType moduleTypeId, address module, bytes calldata data) external payable;

	/// @notice Checks if a module is currently installed
	/// @param moduleTypeId The identifier for the module type
	/// @param module The address of the module
	/// @param additionalContext Optional context for verification
	/// @return installed True if the module is installed, false otherwise
	function isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view returns (bool installed);

	/// @notice Returns a structured ID for the smart account implementation
	/// @return accountImplementationId The implementation identifier in the format "vendor.account.version"
	function accountId() external view returns (string memory accountImplementationId);

	/// @notice Checks if a specific execution mode is supported
	/// @param mode Encoded execution mode
	/// @return supported True if supported, false otherwise
	function supportsExecutionMode(ExecutionMode mode) external view returns (bool supported);

	/// @notice Checks if a specific module type is supported
	/// @param moduleTypeId The identifier for the module type
	/// @return supported True if supported, false otherwise
	function supportsModule(ModuleType moduleTypeId) external view returns (bool supported);

	/// @notice Configures an ERC-7484 registry with a list of trusted attesters and a quorum threshold
	/// @param registry The address of the ERC-7484 registry
	/// @param attesters The list of trusted attesters
	/// @param threshold The minimum number of attestations required
	function configureRegistry(address registry, address[] calldata attesters, uint8 threshold) external payable;

	/// @notice Configures a new root validator module
	/// @param rootValidator The address of the validator module
	/// @param data Initialization context for the validator
	function configureRootValidator(address rootValidator, bytes calldata data) external payable;

	/// @notice Returns the currently configured ERC-7484 registry
	/// @return registry The address of the configured registry
	function registry() external view returns (address registry);

	/// @notice Returns the currently configured root validator module
	/// @return rootValidator The address of the root validator module
	function rootValidator() external view returns (address rootValidator);

	/// @notice Returns globally installed hook modules
	/// @return hooks The list of globally active hook addresses
	function globalHooks() external view returns (address[] memory hooks);

	/// @notice Returns the configuration for a given module
	/// @param module The address of the module
	/// @return moduleTypeId The identifier for the module type
	/// @return packedTypes The bit-packed representation of submodule types
	/// @return hook Optional hook address tied to the module
	function getConfiguration(
		address module
	) external view returns (ModuleType moduleTypeId, PackedModuleTypes packedTypes, address hook);

	/// @notice Returns the fallback module configuration for a function selector
	/// @param selector The function selector to query
	/// @return callType The type of call redirection
	/// @return module The address of the fallback module
	function fallbackHandler(bytes4 selector) external view returns (CallType callType, address module);

	/// @notice Returns a list of forbidden function selectors for fallback routing
	/// @return selectors The list of disallowed function selectors
	function forbiddenSelectors() external pure returns (bytes4[] memory selectors);

	/// @notice Returns the configured EntryPoint
	/// @return The address of the configured EntryPoint
	function entryPoint() external view returns (address);

	/// @notice Deposits ETH into the EntryPoint to cover gas fees for user operations
	function addDeposit() external payable;

	/// @notice Withdraws ETH from the EntryPoint to a specified recipient
	/// @param recipient The address to receive withdrawn ETH
	/// @param amount The amount of ETH to withdraw
	function withdrawTo(address recipient, uint256 amount) external payable;

	/// @notice Returns the current ETH deposit balance at the EntryPoint
	/// @return deposit The amount of ETH deposited
	function getDeposit() external view returns (uint256 deposit);

	/// @notice Returns the nonce for a particular key
	/// @param key The nonce key
	/// @return nonce The nonce associated with the key
	function getNonce(uint192 key) external view returns (uint256 nonce);
}
