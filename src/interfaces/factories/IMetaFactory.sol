// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStakingAdapter} from "../IStakingAdapter.sol";

interface IMetaFactory is IStakingAdapter {
	function createAccount(bytes calldata params) external payable returns (address payable account);

	function computeAddress(address factory, bytes32 salt) external view returns (address payable account);

	function authorize(address factory) external;

	function revoke(address factory) external;

	function isAuthorized(address factory) external view returns (bool);
}
