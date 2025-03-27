// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {IHooks} from "./core/IHooks.sol";

type BalanceDelta is int256;
type BeforeSwapDelta is int256;
type PoolId is bytes32;
type PositionInfo is uint256;

using {toId} for PoolKey global;

struct PoolKey {
	Currency currency0;
	Currency currency1;
	uint24 fee;
	int24 tickSpacing;
	IHooks hooks;
}

struct PathKey {
	Currency intermediateCurrency;
	uint24 fee;
	int24 tickSpacing;
	IHooks hooks;
	bytes hookData;
}

struct ExactInputSingleParams {
	PoolKey poolKey;
	bool zeroForOne;
	uint128 amountIn;
	uint128 amountOutMin;
	bytes hookData;
}

struct ExactInputParams {
	Currency currencyIn;
	PathKey[] path;
	uint128 amountIn;
	uint128 amountOutMin;
}

struct ExactOutputSingleParams {
	PoolKey poolKey;
	bool zeroForOne;
	uint128 amountOut;
	uint128 amountInMax;
	bytes hookData;
}

struct ExactOutputParams {
	Currency currencyOut;
	PathKey[] path;
	uint128 amountOut;
	uint128 amountInMax;
}

function toId(PoolKey memory poolKey) pure returns (PoolId poolId) {
	assembly ("memory-safe") {
		// 0xa0 represents the total size of the poolKey struct (5 slots of 32 bytes)
		poolId := keccak256(poolKey, 0xa0)
	}
}
