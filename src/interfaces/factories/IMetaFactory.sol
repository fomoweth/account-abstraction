// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMetaFactory {
	function createAccount(bytes calldata data) external payable returns (address payable account);

	function addStake(address entryPoint, uint32 unstakeDelaySec) external payable;

	function unlockStake(address entryPoint) external payable;

	function withdrawStake(address entryPoint, address recipient) external payable;

	function setWhitelist(address factory, bool approval) external;

	function isWhitelisted(address factory) external view returns (bool);
}
