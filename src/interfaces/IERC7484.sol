// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC7484 {
	event NewTrustedAttesters(address indexed account);

	function trustAttesters(uint8 threshold, address[] calldata attesters) external;

	function check(address module) external view;

	function checkForAccount(address smartAccount, address module) external view;

	function check(address module, uint256 moduleType) external view;

	function checkForAccount(address smartAccount, address module, uint256 moduleType) external view;

	function check(address module, address[] calldata attesters, uint256 threshold) external view;

	function check(address module, uint256 moduleType, address[] calldata attesters, uint256 threshold) external view;
}
