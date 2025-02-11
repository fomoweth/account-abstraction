// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountFactory} from "./IAccountFactory.sol";

interface IRegistryFactory is IAccountFactory {
	function configureAttesters(address[] calldata attesters, uint8 threshold) external payable;

	function isAuthorized(address attester) external view returns (bool);

	function getAttestersLength() external view returns (uint256 length);

	function getAttesters() external view returns (address[] memory attesters);

	function getThreshold() external view returns (uint8 threshold);
}
