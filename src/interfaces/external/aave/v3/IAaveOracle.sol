// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "src/types/Currency.sol";

interface IAaveOracle {
	event WethSet(address indexed weth);

	event BaseCurrencySet(Currency indexed baseCurrency, uint256 baseCurrencyUnit);

	event AssetSourceUpdated(Currency indexed asset, address indexed source);

	event FallbackOracleUpdated(address indexed fallbackOracle);

	function ADDRESSES_PROVIDER() external view returns (address);

	function WETH() external view returns (Currency);

	function BASE_CURRENCY() external view returns (Currency);

	function BASE_CURRENCY_UNIT() external view returns (uint256);

	function setAssetSources(Currency[] calldata assets, address[] calldata sources) external;

	function getAssetPrice(Currency asset) external view returns (uint256);

	function getAssetsPrices(Currency[] calldata assets) external view returns (uint256[] memory);

	function getSourceOfAsset(Currency asset) external view returns (address);

	function getFallbackOracle() external view returns (address);

	function setFallbackOracle(address fallbackOracle) external;

	// Ownable

	function owner() external view returns (address);

	function renounceOwnership() external;

	function transferOwnership(address newOwner) external;
}
