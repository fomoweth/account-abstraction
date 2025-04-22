// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IStakingAdapter
/// @notice Interface for the StakingAdapter contract
interface IStakingAdapter {
	/// @notice Thrown when the provided EntryPoint address is invalid
	error InvalidEntryPoint();

	/// @notice Thrown when the provided entity address is invalid
	error InvalidEntity();

	/// @notice Thrown when the provided recipient address is invalid
	error InvalidRecipient();

	/// @notice Thrown when the provided deposit amount is invalid
	error InvalidDepositAmount();

	/// @notice Thrown when the provided withdraw amount is invalid
	error InvalidWithdrawAmount();

	/// @notice Thrown when the provided stake amount is invalid
	error InvalidStakeAmount();

	/// @notice Thrown when the provided unstake delay is invalid
	error InvalidUnstakeDelaySec();

	/// @notice Deposits ETH into the EntryPoint on behalf of the entity
	/// @param entryPoint The address of the EntryPoint
	function deposit(address entryPoint) external payable;

	/// @notice Withdraws ETH from the deposit balance in the EntryPoint to the given recipient
	/// @param entryPoint The address of the EntryPoint
	/// @param recipient The address to receive the withdrawn ETH
	/// @param amount The amount of ETH to withdraw
	function withdraw(address entryPoint, address recipient, uint256 amount) external payable;

	/// @notice Stakes ETH in the EntryPoint on behalf of the entity
	/// @param entryPoint The address of the EntryPoint
	/// @param unstakeDelaySec The duration (in seconds) the stake must remain locked before withdrawal is allowed
	function stake(address entryPoint, uint32 unstakeDelaySec) external payable;

	/// @notice Initiates the unlocking process for previously staked ETH in the EntryPoint
	/// @dev After this call, the stake becomes withdrawable only after the unstake delay has elapsed
	/// @param entryPoint The address of the EntryPoint
	function unlock(address entryPoint) external payable;

	/// @notice Withdraws ETH that was previously staked and unlocked from the EntryPoint to the given recipient
	/// @dev Can only be called after the unstake delay has elapsed
	/// @param entryPoint The address of the EntryPoint
	/// @param recipient The address to receive the withdrawn staked ETH
	function unstake(address entryPoint, address recipient) external payable;

	/// @notice Returns the ETH deposit balance for the specified entity on the EntryPoint
	/// @param entryPoint The address of the EntryPoint
	/// @param entity The address whose deposit balance is being queried
	/// @return deposit Current deposit balance of the entity in ETH
	function balanceOf(address entryPoint, address entity) external view returns (uint256 deposit);
}
