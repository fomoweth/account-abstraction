// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStakingAdapter {
	function balanceOf(address entryPoint, address account) external view returns (uint256 deposit);

	function getDepositInfo(
		address entryPoint,
		address account
	) external view returns (uint256 deposit, bool staked, uint112 stake, uint32 unstakeDelaySec, uint48 withdrawTime);

	function depositTo(address entryPoint, address account) external payable;

	function withdrawTo(address entryPoint, address recipient, uint256 amount) external payable;

	function addStake(address entryPoint, uint32 unstakeDelaySec) external payable;

	function unlockStake(address entryPoint) external payable;

	function withdrawStake(address entryPoint, address recipient) external payable;
}
