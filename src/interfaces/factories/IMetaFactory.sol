// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStakingAdapter} from "../IStakingAdapter.sol";

interface IMetaFactory is IStakingAdapter {
	function createAccount(bytes calldata params) external payable returns (address payable account);

	function computeAddress(address factory, bytes32 salt) external view returns (address payable account);

	function deployModule(
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module);

	function computeAddress(bytes32 salt, bytes calldata initCode) external view returns (address instance);

	function parameters() external view returns (bytes memory context);

	function authorize(address factory) external;

	function revoke(address factory) external;

	function isAuthorized(address factory) external view returns (bool);
}
