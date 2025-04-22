// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IMetaFactory
/// @notice Interface for the MetaFactory contract
interface IMetaFactory {
	/// @notice Thrown when the provided factory address is invalid
	error InvalidFactory();

	/// @notice Thrown when the provided factory address is authorized already
	error FactoryAlreadyAuthorized(address factory);

	/// @notice Thrown when the provided factory address is not authorized
	error FactoryNotAuthorized(address factory);

	/// @notice Emitted when a factory is authorized
	event FactoryAuthorized(address indexed factory);

	/// @notice Emitted when a factory is revoked
	event FactoryRevoked(address indexed factory);

	/// @notice Deploys a new smart account using the provided factory and initialization data
	/// @param params Encoded factory address followed by initialization calldata for the new smart account
	/// @return account The address of the newly deployed smart account
	function createAccount(bytes calldata params) external payable returns (address payable account);

	/// @notice Computes the predicted address of a smart account using deterministic deployment logic
	/// @param factory The address of the factory to deploy the account from
	/// @param salt The unique salt used for address computation
	/// @return account The predicted address of the smart account
	function computeAddress(address factory, bytes32 salt) external view returns (address payable account);

	/// @notice Grants authorization to a factory
	/// @param factory The address of the factory to authorize
	function authorize(address factory) external payable;

	/// @notice Revokes authorization from a factory
	/// @param factory The address of the factory to revoke
	function revoke(address factory) external payable;

	/// @notice Returns whether the given factory is authorized
	/// @param factory The address of the factory to check
	/// @return True if authorized, false otherwise
	function isAuthorized(address factory) external view returns (bool);

	/// @notice Reverts if the given factory is not authorized
	/// @param factory The address of the factory to check
	function checkAuthority(address factory) external view;

	/// @notice Returns the name of the factory
	/// @return The name of the factory
	function name() external view returns (string memory);

	/// @notice Returns the version of the factory
	/// @return The version of the factory
	function version() external view returns (string memory);
}
