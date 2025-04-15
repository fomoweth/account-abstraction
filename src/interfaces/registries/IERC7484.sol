// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType} from "src/types/ModuleType.sol";

interface IERC7484 {
	event NewTrustedAttesters(address indexed account);

	function trustAttesters(uint8 threshold, address[] calldata attesters) external;

	function check(address module) external view;

	function checkForAccount(address smartAccount, address module) external view;

	function check(address module, ModuleType moduleType) external view;

	function checkForAccount(address smartAccount, address module, ModuleType moduleType) external view;

	function check(address module, address[] calldata attesters, uint256 threshold) external view;

	function check(
		address module,
		ModuleType moduleType,
		address[] calldata attesters,
		uint256 threshold
	) external view;
}
