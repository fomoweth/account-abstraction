// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAccountFactory {
	function createAccount(bytes32 salt, bytes calldata data) external payable returns (address payable account);

	function computeAddress(bytes32 salt) external view returns (address payable account);

	function ACCOUNT_IMPLEMENTATION() external view returns (address);
}
