// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode, CallType, ExecType, ModuleType} from "src/types/Types.sol";

interface IERC7579Account {
	/**
	 * @notice Executes a transaction on behalf of the account. MAY be payable.
	 * @param mode The encoded execution mode of the transaction.
	 * @param executionCalldata The encoded execution call data.
	 *
	 * MUST ensure adequate authorization control: e.g. onlyEntryPointOrSelf if used with ERC-4337
	 * If a mode is requested that is not supported by the Account, it MUST revert
	 */
	function execute(ExecutionMode mode, bytes calldata executionCalldata) external payable;

	/**
	 * @notice Executes a transaction on behalf of the account. MAY be payable.
	 *         This function is intended to be called by Executor Modules
	 * @param mode The encoded execution mode of the transaction.
	 * @param executionCalldata The encoded execution call data.
	 *
	 * @return returnData An array with the returned data of each executed subcall
	 *
	 * MUST ensure adequate authorization control: i.e. onlyExecutorModule
	 * If a mode is requested that is not supported by the Account, it MUST revert
	 */
	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable returns (bytes[] memory returnData);

	/**
	 * @dev ERC-1271 isValidSignature
	 *         This function is intended to be used to validate a smart account signature
	 * and may forward the call to a validator module
	 *
	 * @param hash The hash of the data that is signed
	 * @param signature The data that is signed
	 */
	function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);

	/**
	 * @notice Installs a Module of a certain type on the smart account
	 * @param moduleTypeId the module type ID according to the ERC-7579 spec
	 * @param module the module address
	 * @param data arbitrary data that may be required on the module during `onInstall`
	 * initialization.
	 *
	 * MUST implement authorization control
	 * MUST call `onInstall` on the module with the `data` parameter if provided
	 * MUST emit ModuleInstalled event
	 * MUST revert if the module is already installed or the initialization on the module failed
	 */
	function installModule(ModuleType moduleTypeId, address module, bytes calldata data) external payable;

	/**
	 * @notice Uninstalls a Module of a certain type on the smart account
	 * @param moduleTypeId the module type ID according the ERC-7579 spec
	 * @param module the module address
	 * @param data arbitrary data that may be required on the module during `onInstall`
	 * initialization.
	 *
	 * MUST implement authorization control
	 * MUST call `onUninstall` on the module with the `data` parameter if provided
	 * MUST emit ModuleUninstalled event
	 * MUST revert if the module is not installed or the deInitialization on the module failed
	 */
	function uninstallModule(ModuleType moduleTypeId, address module, bytes calldata data) external payable;

	/**
	 * @notice Returns whether a module is installed on the smart account
	 * @param moduleTypeId the module type ID according the ERC-7579 spec
	 * @param module the module address
	 * @param additionalContext arbitrary data that may be required to determine if the module is installed
	 *
	 * MUST return true if the module is installed and false otherwise
	 */
	function isModuleInstalled(
		ModuleType moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view returns (bool);

	/**
	 * @notice Returns the account id of the smart account
	 * @return accountImplementationId the account id of the smart account
	 *
	 * MUST return a non-empty string
	 * The accountId SHOULD be structured like so:
	 *        "vendorname.accountname.semver"
	 * The id SHOULD be unique across all smart accounts
	 */
	function accountId() external view returns (string memory accountImplementationId);

	/**
	 * @notice Function to check if the account supports a certain execution mode (see above)
	 * @param mode the encoded mode
	 *
	 * MUST return true if the account supports the mode and false otherwise
	 */
	function supportsExecutionMode(ExecutionMode mode) external view returns (bool);

	/**
	 * @notice Function to check if the account supports a certain module typeId
	 * @param moduleTypeId the module type ID according to the ERC-7579 spec
	 *
	 * MUST return true if the account supports the module type and false otherwise
	 */
	function supportsModule(ModuleType moduleTypeId) external view returns (bool);
}
