// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ValidationData} from "src/types/Types.sol";

interface IERC4337Account {
	/**
	 * Validate user's signature and nonce
	 * the entryPoint will make the call to the recipient only if this validation call returns successfully.
	 * signature failure should be reported by returning SIG_VALIDATION_FAILED (1).
	 * This allows making a "simulation call" without a valid signature
	 * Other failures (e.g. nonce mismatch, or invalid signature format) should still revert to signal failure.
	 *
	 * @dev Must validate caller is the entryPoint.
	 *      Must validate the signature and nonce
	 * @param userOp              - The operation that is about to be executed.
	 * @param userOpHash          - Hash of the user's request data. can be used as the basis for signature.
	 * @param missingAccountFunds - Missing funds on the account's deposit in the entrypoint.
	 *                              This is the minimum amount to transfer to the sender(entryPoint) to be
	 *                              able to make the call. The excess is left as a deposit in the entrypoint
	 *                              for future calls. Can be withdrawn anytime using "entryPoint.withdrawTo()".
	 *                              In case there is a paymaster in the request (or the current deposit is high
	 *                              enough), this value will be zero.
	 * @return validationData       - Packaged ValidationData structure. use `_packValidationData` and
	 *                              `_unpackValidationData` to encode and decode.
	 *                              <20-byte> sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
	 *                                 otherwise, an address of an "authorizer" contract.
	 *                              <6-byte> validUntil - Last timestamp this operation is valid. 0 for "indefinite"
	 *                              <6-byte> validAfter - First timestamp this operation is valid
	 *                                                    If an account doesn't use time-range, it is enough to
	 *                                                    return SIG_VALIDATION_FAILED value (1) for signature failure.
	 *                              Note that the validation code cannot use block.timestamp (or block.number) directly.
	 */
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable returns (ValidationData validationData);

	/**
	 * Account may implement this execute method.
	 * passing this methodSig at the beginning of callData will cause the entryPoint to pass the full UserOp (and hash)
	 * to the account.
	 * The account should skip the methodSig, and use the callData (and optionally, other UserOp fields)
	 *
	 * @param userOp              - The operation that was just validated.
	 * @param userOpHash          - Hash of the user's request data.
	 */
	function executeUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external payable;

	/**
	 * @notice Retrieves the address of the EntryPoint contract used by this account.
	 * @return The address of the EntryPoint contract.
	 */
	function entryPoint() external view returns (address);

	/**
	 * @notice Adds deposit to the EntryPoint to fund transactions.
	 */
	function addDeposit() external payable;

	/**
	 * @notice Withdraws ETH from the EntryPoint to a specified address.
	 * @param recipient The address to receive the withdrawn funds.
	 * @param amount The amount to withdraw.
	 */
	function withdrawTo(address recipient, uint256 amount) external payable;

	/**
	 * @notice Returns the current deposit balance of this account on the EntryPoint.
	 * @return The current balance held at the EntryPoint.
	 */
	function getDeposit() external view returns (uint256);

	/**
	 * @notice Gets the nonce for a particular key.
	 * @param key The nonce key.
	 * @return The nonce associated with the key.
	 */
	function getNonce(uint192 key) external view returns (uint256);
}
