// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {Currency} from "src/types/Currency.sol";
import {IAllowanceTransfer} from "../../permit2/IAllowanceTransfer.sol";
import {PathKey, PoolKey, PositionInfo} from "../V4Types.sol";
import {IImmutableState} from "./IImmutableState.sol";
import {INotifier} from "./INotifier.sol";

/// @title IPositionManager
/// @notice Interface for the PositionManager contract
interface IPositionManager is IERC721, IImmutableState, INotifier {
	/// @notice Thrown when the caller is not approved to modify a position
	error NotApproved(address caller);
	/// @notice Thrown when the block.timestamp exceeds the user-provided deadline
	error DeadlinePassed(uint256 deadline);
	/// @notice Thrown when calling transfer, subscribe, or unsubscribe when the PoolManager is unlocked.
	/// @dev This is to prevent hooks from being able to trigger notifications at the same time the position is being modified.
	error PoolManagerMustBeLocked();

	/// @notice Unlocks Uniswap v4 PoolManager and batches actions for modifying liquidity
	/// @dev This is the standard entrypoint for the PositionManager
	/// @param unlockData is an encoding of actions, and parameters for those actions
	/// @param deadline is the deadline for the batched actions to be executed
	function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;

	/// @notice Batches actions for modifying liquidity without unlocking v4 PoolManager
	/// @dev This must be called by a contract that has already unlocked the v4 PoolManager
	/// @param actions the actions to perform
	/// @param params the parameters to provide for the actions
	function modifyLiquiditiesWithoutUnlock(bytes calldata actions, bytes[] calldata params) external payable;

	/// @notice Used to get the ID that will be used for the next minted liquidity position
	/// @return uint256 The next token ID
	function nextTokenId() external view returns (uint256);

	/// @notice Returns the liquidity of a position
	/// @param tokenId the ERC721 tokenId
	/// @return liquidity the position's liquidity, as a liquidityAmount
	/// @dev this value can be processed as an amount0 and amount1 by using the LiquidityAmounts library
	function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);

	/// @notice Returns the pool key and position info of a position
	/// @param tokenId the ERC721 tokenId
	/// @return poolKey the pool key of the position
	/// @return PositionInfo a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
	function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory, PositionInfo);

	/// @notice Returns the position info of a position
	/// @param tokenId the ERC721 tokenId
	/// @return a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
	function positionInfo(uint256 tokenId) external view returns (PositionInfo);

	/// IPoolInitializer_v4

	/// @notice Initialize a Uniswap v4 Pool
	/// @dev If the pool is already initialized, this function will not revert and just return type(int24).max
	/// @param key The PoolKey of the pool to initialize
	/// @param sqrtPriceX96 The initial starting price of the pool, expressed as a sqrtPriceX96
	/// @return The current tick of the pool, or type(int24).max if the pool creation failed, or the pool already existed
	function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);

	/// IEIP712_v4

	/// @notice Returns the domain separator for the current chain.
	/// @return bytes32 The domain separator
	function DOMAIN_SEPARATOR() external view returns (bytes32);

	/// IERC721Permit_v4

	error SignatureDeadlineExpired();
	error NoSelfPermit();
	error Unauthorized();

	/// @notice Approve of a specific token ID for spending by spender via signature
	/// @param spender The account that is being approved
	/// @param tokenId The ID of the token that is being approved for spending
	/// @param deadline The deadline timestamp by which the call must be mined for the approve to work
	/// @param nonce a unique value, for an owner, to prevent replay attacks; an unordered nonce where the top 248 bits correspond to a word and the bottom 8 bits calculate the bit position of the word
	/// @param signature Concatenated data from a valid secp256k1 signature from the holder, i.e. abi.encodePacked(r, s, v)
	/// @dev payable so it can be multicalled with NATIVE related actions
	function permit(
		address spender,
		uint256 tokenId,
		uint256 deadline,
		uint256 nonce,
		bytes calldata signature
	) external payable;

	/// @notice Set an operator with full permission to an owner's tokens via signature
	/// @param owner The address that is setting the operator
	/// @param operator The address that will be set as an operator for the owner
	/// @param approved The permission to set on the operator
	/// @param deadline The deadline timestamp by which the call must be mined for the approve to work
	/// @param nonce a unique value, for an owner, to prevent replay attacks; an unordered nonce where the top 248 bits correspond to a word and the bottom 8 bits calculate the bit position of the word
	/// @param signature Concatenated data from a valid secp256k1 signature from the holder, i.e. abi.encodePacked(r, s, v)
	/// @dev payable so it can be multicalled with NATIVE related actions
	function permitForAll(
		address owner,
		address operator,
		bool approved,
		uint256 deadline,
		uint256 nonce,
		bytes calldata signature
	) external payable;

	/// IPermit2Forwarder

	/// @notice allows forwarding a single permit to permit2
	/// @dev this function is payable to allow multicall with NATIVE based actions
	/// @param owner the owner of the tokens
	/// @param permitSingle the permit data
	/// @param signature the signature of the permit; abi.encodePacked(r, s, v)
	/// @return err the error returned by a reverting permit call, empty if successful
	function permit(
		address owner,
		IAllowanceTransfer.PermitSingle calldata permitSingle,
		bytes calldata signature
	) external payable returns (bytes memory err);

	/// @notice allows forwarding batch permits to permit2
	/// @dev this function is payable to allow multicall with NATIVE based actions
	/// @param owner the owner of the tokens
	/// @param _permitBatch a batch of approvals
	/// @param signature the signature of the permit; abi.encodePacked(r, s, v)
	/// @return err the error returned by a reverting permit call, empty if successful
	function permitBatch(
		address owner,
		IAllowanceTransfer.PermitBatch calldata _permitBatch,
		bytes calldata signature
	) external payable returns (bytes memory err);

	/// IUnorderedNonce
	error NonceAlreadyUsed();

	/// @notice mapping of nonces consumed by each address, where a nonce is a single bit on the 256-bit bitmap
	/// @dev word is at most type(uint248).max
	function nonces(address owner, uint256 word) external view returns (uint256);

	/// @notice Revoke a nonce by spending it, preventing it from being used again
	/// @dev Used in cases where a valid nonce has not been broadcasted onchain, and the owner wants to revoke the validity of the nonce
	/// @dev payable so it can be multicalled with native-token related actions
	function revokeNonce(uint256 nonce) external payable;

	/// IMulticall_v4

	/// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
	/// @dev The `msg.value` is passed onto all subcalls, even if a previous subcall has consumed the ether.
	/// Subcalls can instead use `address(this).value` to see the available ETH, and consume it using {value: x}.
	/// @param data The encoded function data for each of the calls to make to this contract
	/// @return results The results from each of the calls passed in via data
	function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
