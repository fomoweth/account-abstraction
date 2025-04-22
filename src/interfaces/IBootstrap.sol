// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct BootstrapConfig {
	address module;
	bytes data;
}

interface IBootstrap {
	/// @notice Initializes the smart account with the root validator and other modules
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param validators Bootstrap configurations for validator modules
	/// @param executors Bootstrap configurations for executor modules
	/// @param fallbacks Bootstrap configurations for fallback modules
	/// @param hooks Bootstrap configurations for hook modules
	/// @param preValidationHook1271 Bootstrap configurations for ERC-1271 preValidation hook module
	/// @param preValidationHook4337 Bootstrap configurations for ERC-4337 preValidation hook module
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	function initialize(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable;

	/// @notice Initializes the smart account with the root validator and other modules
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param validators Bootstrap configurations for validator modules
	/// @param executors Bootstrap configurations for executor modules
	/// @param fallbacks Bootstrap configurations for fallback modules
	/// @param hooks Bootstrap configurations for hook modules
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	function initializeScoped(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable;

	/// @notice Initializes the smart account with the root validator
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	function initializeWithRootValidator(
		BootstrapConfig calldata rootValidator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable;

	/// @notice Prepares calldata for the initialize function
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param validators Bootstrap configurations for validator modules
	/// @param executors Bootstrap configurations for executor modules
	/// @param fallbacks Bootstrap configurations for fallback modules
	/// @param hooks Bootstrap configurations for hook modules
	/// @param preValidationHook1271 Bootstrap configurations for ERC-1271 preValidation hook module
	/// @param preValidationHook4337 Bootstrap configurations for ERC-4337 preValidation hook module
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	/// @return callData The prepared calldata for initialize
	function getInitializeCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData);

	/// @notice Prepares calldata for the initializeScoped function
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param validators Bootstrap configurations for validator modules
	/// @param executors Bootstrap configurations for executor modules
	/// @param fallbacks Bootstrap configurations for fallback modules
	/// @param hooks Bootstrap configurations for hook modules
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	/// @return callData The prepared calldata for initializeScoped
	function getInitializeScopedCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData);

	/// @notice Prepares calldata for the initializeWithRootValidator function
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	/// @return callData The prepared calldata for initializeScoped
	function getInitializeWithRootValidatorCalldata(
		BootstrapConfig calldata rootValidator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData);
}
