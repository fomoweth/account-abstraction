// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IValidator} from "./IERC7579Modules.sol";

interface IK1Validator is IValidator {
	error InvalidSender();
	error SenderAlreadyExists(address sender);
	error SenderNotExists(address sender);

	function transferOwnership(address owner) external;

	function getAccountOwner(address account) external view returns (address);

	function addSafeSender(address sender) external;

	function removeSafeSender(address sender) external;

	function getSafeSenders(address account) external view returns (address[] memory senders);

	function isSafeSender(address account, address sender) external view returns (bool);
}
