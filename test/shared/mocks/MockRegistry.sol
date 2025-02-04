// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC7484} from "src/interfaces/registries/IERC7484.sol";

contract MockRegistry is IERC7484 {
	event Log(address sender);

	mapping(address account => bool isInstalled) public isInstalled;

	function check(address module) public view {}

	function checkForAccount(address account, address module) public view {}

	function check(address module, uint256 moduleTypeId) public view {}

	function checkForAccount(address account, address module, uint256 moduleTypeId) public view {}

	function check(address module, address[] calldata attesters, uint256 threshold) public view {}

	function check(address module, uint256 moduleTypeId, address[] calldata attesters, uint256 threshold) public view {}

	function trustAttesters(uint8 threshold, address[] calldata attesters) public {
		threshold;
		attesters;
		emit Log(msg.sender);
		emit NewTrustedAttesters(msg.sender);
	}

	function name() public pure returns (string memory) {
		return "MockRegistry";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}
}
