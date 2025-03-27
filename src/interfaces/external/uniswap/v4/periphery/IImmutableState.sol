// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPoolManager} from "../core/IPoolManager.sol";

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
	/// @notice The Uniswap v4 PoolManager contract
	function poolManager() external view returns (IPoolManager);
}
