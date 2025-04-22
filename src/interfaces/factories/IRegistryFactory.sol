// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "../IBootstrap.sol";
import {IAccountFactory} from "./IAccountFactory.sol";

/// @title IRegistryFactory
/// @notice Interface for the RegistryFactory contract
interface IRegistryFactory is IAccountFactory {
	/// @notice Thrown when the provided attester address is already registered
	error AttesterAlreadyExists(address attester);

	/// @notice Thrown when the specified attester address is not registered
	error AttesterNotExists(address attester);

	/// @notice Thrown when the number of attesters exceeds the allowed limit
	error ExceededMaxAttesters();

	/// @notice Thrown when the provided attester address is invalid
	error InvalidAttester();

	/// @notice Thrown when the provided list of attester addresses is invalid
	error InvalidTrustedAttesters();

	/// @notice Thrown when the threshold value is outside the valid range
	error InvalidThreshold();

	/// @notice Thrown when the provided module address is invalid
	error InvalidModule();

	/// @notice Thrown when the module has not been authorized via ERC-7484 attestation
	error ModuleNotAuthorized(address module);

	/// @notice Deploys a new smart account with the given module initialization configs
	/// @param salt The salt used for deterministic deployment
	/// @param rootValidator Bootstrap configuration for the root validator module
	/// @param validators Bootstrap configurations for validator modules
	/// @param executors Bootstrap configurations for executor modules
	/// @param fallbacks Bootstrap configurations for fallback modules
	/// @param hooks Bootstrap configurations for hook modules
	/// @return account The address of the deployed smart account
	function createAccount(
		bytes32 salt,
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337
	) external payable returns (address payable account);

	/// @notice Sets the list of trusted attesters and the authorization threshold
	/// @param attesters The list of addresses to authorize as attesters
	/// @param threshold The minimum number of attesters required for authorization
	function configure(address[] calldata attesters, uint8 threshold) external payable;

	/// @notice Authorizes a new attester
	/// @param attester The address to authorize
	function authorize(address attester) external payable;

	/// @notice Revokes an existing attester
	/// @param attester The address to revoke
	function revoke(address attester) external payable;

	/// @notice Sets the required threshold for attester approvals
	/// @param threshold The new minimum number of required attestations
	function setThreshold(uint8 threshold) external payable;

	/// @notice Returns whether a given address is a trusted attester
	/// @param attester The address of the attester
	/// @return True if authorized, false otherwise
	function isAuthorized(address attester) external view returns (bool);

	/// @notice Returns the list of currently authorized attesters
	/// @return attesters The list of trusted attester addresses
	function getTrustedAttesters() external view returns (address[] memory attesters);

	/// @notice Returns the currently configured attestation threshold
	/// @return threshold The number of attestations required for authorization
	function getThreshold() external view returns (uint8 threshold);
}
