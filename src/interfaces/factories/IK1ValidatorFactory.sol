// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountFactory} from "./IAccountFactory.sol";

/// @title IK1ValidatorFactory
/// @notice Interface for the K1ValidatorFactory contract
interface IK1ValidatorFactory is IAccountFactory {
	/// @notice Deploys a new smart account initialized with K1Validator-specific configuration
	/// @param salt The unique value used for deterministic deployment of the smart account
	/// @param eoaOwner The externally owned account (EOA) set as the smart account owner
	/// @param senders The list of addresses authorized as senders for the K1Validator module
	/// @param registry The address of the ERC-7484 registry to be associated with the smart account
	/// @param attesters The list of trusted attester addresses for identity or permission verification
	/// @param threshold The minimum number of attesters required to validate an assertion or operation
	/// @return account The address of the newly deployed smart account
	function createAccount(
		bytes32 salt,
		address eoaOwner,
		address[] calldata senders,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable returns (address payable);
}
