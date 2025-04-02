// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountFactory} from "./IAccountFactory.sol";

interface IK1ValidatorFactory is IAccountFactory {
	function createAccount(
		bytes32 salt,
		address eoaOwner,
		address[] calldata senders,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable returns (address payable);
}
