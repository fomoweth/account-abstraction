// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "src/types/Currency.sol";

interface IV3Quoter {
	struct QuoteExactInputSingleWithPoolParams {
		Currency currencyIn;
		Currency currencyOut;
		uint256 amountIn;
		address pool;
		uint24 fee;
		uint160 sqrtPriceLimitX96;
	}

	function quoteExactInputSingleWithPool(
		QuoteExactInputSingleWithPoolParams memory params
	)
		external
		view
		returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

	struct QuoteExactInputSingleParams {
		Currency currencyIn;
		Currency currencyOut;
		uint256 amountIn;
		uint24 fee;
		uint160 sqrtPriceLimitX96;
	}

	function quoteExactInputSingle(
		QuoteExactInputSingleParams memory params
	)
		external
		view
		returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

	function quoteExactInput(
		bytes memory path,
		uint256 amountIn
	)
		external
		view
		returns (
			uint256 amountOut,
			uint160[] memory sqrtPriceX96AfterList,
			uint32[] memory initializedTicksCrossedList,
			uint256 gasEstimate
		);

	struct QuoteExactOutputSingleWithPoolParams {
		Currency currencyIn;
		Currency currencyOut;
		uint256 amountOut;
		uint24 fee;
		address pool;
		uint160 sqrtPriceLimitX96;
	}

	function quoteExactOutputSingleWithPool(
		QuoteExactOutputSingleWithPoolParams memory params
	)
		external
		view
		returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

	struct QuoteExactOutputSingleParams {
		Currency currencyIn;
		Currency currencyOut;
		uint256 amountOut;
		uint24 fee;
		uint160 sqrtPriceLimitX96;
	}

	function quoteExactOutputSingle(
		QuoteExactOutputSingleParams memory params
	)
		external
		view
		returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

	function quoteExactOutput(
		bytes memory path,
		uint256 amountOut
	)
		external
		view
		returns (
			uint256 amountIn,
			uint160[] memory sqrtPriceX96AfterList,
			uint32[] memory initializedTicksCrossedList,
			uint256 gasEstimate
		);
}
