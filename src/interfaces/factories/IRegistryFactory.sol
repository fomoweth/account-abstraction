// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "../IBootstrap.sol";
import {IAccountFactory} from "./IAccountFactory.sol";

interface IRegistryFactory is IAccountFactory {
	function createAccount(
		bytes32 salt,
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks
	) external payable returns (address payable account);

	function configureAttesters(address[] calldata attesters, uint8 threshold) external payable;

	function getAttesters() external view returns (address[] memory attesters);

	function getThreshold() external view returns (uint8 threshold);

	function isAuthorized(address attester) external view returns (bool);
}
