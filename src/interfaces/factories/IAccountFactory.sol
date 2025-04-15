// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAccountFactory
/// @notice Interface for the AccountFactory contract
interface IAccountFactory {
	/// @notice Thrown when smart account deployment fails
	error AccountCreationFailed();

	/// @notice Thrown when ETH transfer fails
	error EthTransferFailed();

	/// @notice Thrown when the provided smart account address is invalid
	error InvalidAccountImplementation();

	/// @notice Thrown when the provided bootstrap address is invalid
	error InvalidBootstrap();

	/// @notice Thrown when the provided k1-validator address is invalid
	error InvalidK1Validator();

	/// @notice Thrown when the provided ERC-7484 registry address is invalid
	error InvalidERC7484Registry();

	/// @notice Emitted upon successful deployment of a new smart account
	event AccountCreated(address indexed account, bytes32 indexed salt);

	/// @notice Deploys a new smart account using `CREATE2` with the provided salt and initialization parameters
	/// @param salt The salt used for deterministic address generation
	/// @param params Encoded initialization parameters for the new account
	/// @return account The address of the deployed account
	function createAccount(bytes32 salt, bytes calldata params) external payable returns (address payable account);

	/// @notice Computes the predicted address of a smart account using deterministic deployment logic
	/// @param salt The salt used for address computation
	/// @return account The predicted address of the smart account
	function computeAddress(bytes32 salt) external view returns (address payable account);

	/// @notice Returns the name of the smart account factory
	/// @return The name of the factory
	function name() external view returns (string memory);

	/// @notice Returns the version of the smart account factory
	/// @return The version of the factory
	function version() external view returns (string memory);
}
