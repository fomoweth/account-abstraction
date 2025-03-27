// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniversalRouter {
	/// @notice Thrown when a required command has failed
	error ExecutionFailed(uint256 commandIndex, bytes message);

	/// @notice Thrown when attempting to send ETH directly to the contract
	error ETHNotAccepted();

	/// @notice Thrown when executing commands with an expired deadline
	error TransactionDeadlinePassed();

	/// @notice Thrown when attempting to execute commands and an incorrect number of inputs are provided
	error LengthMismatch();

	/// @notice Thrown when an address that isn't WETH tries to send ETH to the router without calldata
	error InvalidEthSender();

	error V2TooLittleReceived();
	error V2TooMuchRequested();
	error V2InvalidPath();

	error V3InvalidSwap();
	error V3TooLittleReceived();
	error V3TooMuchRequested();
	error V3InvalidAmountOut();
	error V3InvalidCaller();

	/// @notice Emitted when an exactInput swap does not receive its minAmountOut
	error V4TooLittleReceived(uint256 minAmountOutReceived, uint256 amountReceived);
	/// @notice Emitted when an exactOutput is asked for more than its maxAmountIn
	error V4TooMuchRequested(uint256 maxAmountInRequested, uint256 amountRequested);

	error InvalidAction(bytes4 action);
	error OnlyMintAllowed();
	error NotAuthorizedForToken(uint256 tokenId);

	/// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
	/// @param commands A set of concatenated commands, each 1 byte in length
	/// @param inputs An array of byte strings containing abi encoded inputs for each command
	/// @param deadline The deadline by which the transaction must be executed
	function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;

	function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}
