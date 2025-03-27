// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721Metadata} from "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Enumerable} from "@openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import {Currency} from "src/types/Currency.sol";

interface INonfungiblePositionManager is IERC721Metadata, IERC721Enumerable {
	/// @notice Emitted when liquidity is increased for a position NFT
	/// @dev Also emitted when a token is minted
	/// @param tokenId The ID of the token for which liquidity was increased
	/// @param liquidity The amount by which liquidity for the NFT position was increased
	/// @param amount0 The amount of token0 that was paid for the increase in liquidity
	/// @param amount1 The amount of token1 that was paid for the increase in liquidity
	event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
	/// @notice Emitted when liquidity is decreased for a position NFT
	/// @param tokenId The ID of the token for which liquidity was decreased
	/// @param liquidity The amount by which liquidity for the NFT position was decreased
	/// @param amount0 The amount of token0 that was accounted for the decrease in liquidity
	/// @param amount1 The amount of token1 that was accounted for the decrease in liquidity
	event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
	/// @notice Emitted when tokens are collected for a position NFT
	/// @dev The amounts reported may not be exactly equivalent to the amounts transferred, due to rounding behavior
	/// @param tokenId The ID of the token for which underlying tokens were collected
	/// @param recipient The address of the account that received the collected tokens
	/// @param amount0 The amount of token0 owed to the position that was collected
	/// @param amount1 The amount of token1 owed to the position that was collected
	event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

	/// @notice Returns the position information associated with a given token ID.
	/// @dev Throws if the token ID is not valid.
	/// @param tokenId The ID of the token that represents the position
	/// @return nonce The nonce for permits
	/// @return operator The address that is approved for spending
	/// @return currency0 The address of the token0 for a specific pool
	/// @return currency1 The address of the token1 for a specific pool
	/// @return fee The fee associated with the pool
	/// @return tickLower The lower end of the tick range for the position
	/// @return tickUpper The higher end of the tick range for the position
	/// @return liquidity The liquidity of the position
	/// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
	/// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
	/// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
	/// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
	function positions(
		uint256 tokenId
	)
		external
		view
		returns (
			uint96 nonce,
			address operator,
			Currency currency0,
			Currency currency1,
			uint24 fee,
			int24 tickLower,
			int24 tickUpper,
			uint128 liquidity,
			uint256 feeGrowthInside0LastX128,
			uint256 feeGrowthInside1LastX128,
			uint128 tokensOwed0,
			uint128 tokensOwed1
		);

	struct MintParams {
		Currency currency0;
		Currency currency1;
		uint24 fee;
		int24 tickLower;
		int24 tickUpper;
		uint256 amount0Desired;
		uint256 amount1Desired;
		uint256 amount0Min;
		uint256 amount1Min;
		address recipient;
		uint256 deadline;
	}

	/// @notice Creates a new position wrapped in a NFT
	/// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
	/// a method does not exist, i.e. the pool is assumed to be initialized.
	/// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
	/// @return tokenId The ID of the token that represents the minted position
	/// @return liquidity The amount of liquidity for this position
	/// @return amount0 The amount of token0
	/// @return amount1 The amount of token1
	function mint(
		MintParams calldata params
	) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

	struct IncreaseLiquidityParams {
		uint256 tokenId;
		uint256 amount0Desired;
		uint256 amount1Desired;
		uint256 amount0Min;
		uint256 amount1Min;
		uint256 deadline;
	}

	/// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
	/// @param params tokenId The ID of the token for which liquidity is being increased,
	/// amount0Desired The desired amount of token0 to be spent,
	/// amount1Desired The desired amount of token1 to be spent,
	/// amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
	/// amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
	/// deadline The time by which the transaction must be included to effect the change
	/// @return liquidity The new liquidity amount as a result of the increase
	/// @return amount0 The amount of token0 to achieve resulting liquidity
	/// @return amount1 The amount of token1 to achieve resulting liquidity
	function increaseLiquidity(
		IncreaseLiquidityParams calldata params
	) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

	struct DecreaseLiquidityParams {
		uint256 tokenId;
		uint128 liquidity;
		uint256 amount0Min;
		uint256 amount1Min;
		uint256 deadline;
	}

	/// @notice Decreases the amount of liquidity in a position and accounts it to the position
	/// @param params tokenId The ID of the token for which liquidity is being decreased,
	/// amount The amount by which liquidity will be decreased,
	/// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
	/// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
	/// deadline The time by which the transaction must be included to effect the change
	/// @return amount0 The amount of token0 accounted to the position's tokens owed
	/// @return amount1 The amount of token1 accounted to the position's tokens owed
	function decreaseLiquidity(
		DecreaseLiquidityParams calldata params
	) external payable returns (uint256 amount0, uint256 amount1);

	struct CollectParams {
		uint256 tokenId;
		address recipient;
		uint128 amount0Max;
		uint128 amount1Max;
	}

	/// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
	/// @param params tokenId The ID of the NFT for which tokens are being collected,
	/// recipient The account that should receive the tokens,
	/// amount0Max The maximum amount of token0 to collect,
	/// amount1Max The maximum amount of token1 to collect
	/// @return amount0 The amount of fees collected in token0
	/// @return amount1 The amount of fees collected in token1
	function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

	/// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
	/// must be collected first.
	/// @param tokenId The ID of the token that is being burned
	function burn(uint256 tokenId) external payable;

	/// IPoolInitializer

	/// @notice Creates a new pool if it does not exist, then initializes if not initialized
	/// @dev This method can be bundled with others via IMulticall for the first action (e.g. mint) performed against a pool
	/// @param currency0 The contract address of token0 of the pool
	/// @param currency1 The contract address of token1 of the pool
	/// @param fee The fee amount of the v3 pool for the specified token pair
	/// @param sqrtPriceX96 The initial square root price of the pool as a Q64.96 value
	/// @return pool Returns the pool address based on the pair of tokens and fee, will return the newly created pool address if necessary
	function createAndInitializePoolIfNecessary(
		Currency currency0,
		Currency currency1,
		uint24 fee,
		uint160 sqrtPriceX96
	) external payable returns (address pool);

	/// IPeripheryPayments

	/// @notice Unwraps the contract's WETH9 balance and sends it to recipient as ETH.
	/// @dev The amountMinimum parameter prevents malicious contracts from stealing WETH9 from users.
	/// @param amountMinimum The minimum amount of WETH9 to unwrap
	/// @param recipient The address receiving ETH
	function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

	/// @notice Refunds any ETH balance held by this contract to the `msg.sender`
	/// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
	/// that use ether for the input amount
	function refundETH() external payable;

	/// @notice Transfers the full amount of a token held by this contract to recipient
	/// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
	/// @param currency The contract address of the token which will be transferred to `recipient`
	/// @param amountMinimum The minimum amount of token required for a transfer
	/// @param recipient The destination address of the token
	function sweepToken(Currency currency, uint256 amountMinimum, address recipient) external payable;

	/// IPeripheryImmutableState

	/// @return Returns the address of the Uniswap V3 factory
	function factory() external view returns (address);

	/// @return Returns the address of WETH9
	function WETH9() external view returns (Currency);

	/// IERC721Permit

	/// @notice The permit typehash used in the permit signature
	/// @return The typehash for the permit
	function PERMIT_TYPEHASH() external pure returns (bytes32);

	/// @notice The domain separator used in the permit signature
	/// @return The domain seperator used in encoding of permit signature
	function DOMAIN_SEPARATOR() external view returns (bytes32);

	/// @notice Approve of a specific token ID for spending by spender via signature
	/// @param spender The account that is being approved
	/// @param tokenId The ID of the token that is being approved for spending
	/// @param deadline The deadline timestamp by which the call must be mined for the approve to work
	/// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
	/// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
	/// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
	function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;

	/// IMulticall

	/// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
	/// @dev The `msg.value` should not be trusted for any method callable from multicall.
	/// @param data The encoded function data for each of the calls to make to this contract
	/// @return results The results from each of the calls passed in via data
	function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
