// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IModuleFactory
/// @notice Interface for the ModuleFactory contract
interface IModuleFactory {
	/// @notice Thrown when the provided bytecode is empty
	error EmptyBytecode();

	/// @notice Thrown when the encoded constructor parameters exceed the maximum allowed length
	error ExceededMaxParamsLength();

	/// @notice Thrown when the deployment of the module fails
	error ModuleDeploymentFailed();

	/// @notice Emitted upon successful deployment of a new ERC-7579 module
	/// @param module The address of the deployed module
	/// @param salt The salt used for deterministic deployment
	event ModuleDeployed(address indexed module, bytes32 indexed salt);

	/// @notice Deploys a new ERC-7579 module using `CREATE2` with external resolver-based registration
	/// @param registry The address of the ERC-7484 registry
	/// @param resolverUID The UID of the resolver used for registration
	/// @param salt The salt used for deterministic address generation
	/// @param bytecode Runtime bytecode of the module
	/// @param params Encoded constructor arguments of the module
	/// @return module The address of the deployed module
	function deployModule(
		address registry,
		bytes32 resolverUID,
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module);

	/// @notice Deploys a new ERC-7579 module using `CREATE2` with external resolver-based registration
	/// @param salt The salt used for deterministic address generation
	/// @param bytecode Runtime bytecode of the module
	/// @param params Encoded constructor arguments of the module
	/// @return module The address of the deployed module
	function deployModule(
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module);

	/// @notice Computes the predicted address of ERC-7579 module using deterministic deployment logic
	/// @param salt The salt used for address computation
	/// @param initCode Full initialization code (bytecode + constructor args)
	/// @return module The predicted address of the module
	function computeAddress(bytes32 salt, bytes calldata initCode) external view returns (address module);

	/// @notice Returns the encoded parameters to be used within the constructor during deployment
	/// @return context Encoded constructor arguments
	function parameters() external view returns (bytes memory context);

	/// @notice Returns the name of the module factory
	/// @return The name of the factory
	function name() external view returns (string memory);

	/// @notice Returns the version of the module factory
	/// @return The version of the factory
	function version() external view returns (string memory);
}
