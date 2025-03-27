// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IScaledBalanceToken {
	function scaledTotalSupply() external view returns (uint256);

	function scaledBalanceOf(address user) external view returns (uint256);

	function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

	function getPreviousIndex(address user) external view returns (uint256);
}
