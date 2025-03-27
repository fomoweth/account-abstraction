// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";

interface IUniswapV2Factory {
	event PairCreated(Currency indexed currency0, Currency indexed currency1, IUniswapV2Pair pair, uint256);

	function feeTo() external view returns (address);

	function feeToSetter() external view returns (address);

	function getPair(Currency currencyA, Currency currencyB) external view returns (IUniswapV2Pair pair);

	function allPairs(uint256 index) external view returns (IUniswapV2Pair pair);

	function allPairsLength() external view returns (uint256);

	function createPair(Currency currencyA, Currency currencyB) external returns (IUniswapV2Pair pair);

	function setFeeTo(address to) external;

	function setFeeToSetter(address to) external;
}
