// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISmartAccountFactory {
	function createAccount(bytes calldata data, bytes32 salt) external payable returns (address payable account);

	function computeAddress(bytes calldata data, bytes32 salt) external view returns (address payable account);

	function implementation() external view returns (address);
}
