// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";

interface IVariableDebtToken is IERC20Metadata, IScaledBalanceToken {
	event Mint(
		address indexed caller,
		address indexed onBehalfOf,
		uint256 value,
		uint256 balanceIncrease,
		uint256 index
	);

	event Burn(address indexed from, address indexed target, uint256 value, uint256 balanceIncrease, uint256 index);

	// ICreditDelegationToken

	event BorrowAllowanceDelegated(
		address indexed fromUser,
		address indexed toUser,
		address indexed asset,
		uint256 amount
	);

	function approveDelegation(address delegatee, uint256 amount) external;

	function borrowAllowance(address fromUser, address toUser) external view returns (uint256);

	function delegationWithSig(
		address delegator,
		address delegatee,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external;

	// IInitializableDebtToken

	event Initialized(
		address indexed underlyingAsset,
		address indexed pool,
		address incentivesController,
		uint8 debtTokenDecimals,
		string debtTokenName,
		string debtTokenSymbol,
		bytes params
	);

	function initialize(
		address pool,
		address underlyingAsset,
		address incentivesController,
		uint8 debtTokenDecimals,
		string memory debtTokenName,
		string memory debtTokenSymbol,
		bytes calldata params
	) external;

	// IVariableDebtToken

	function mint(address user, address onBehalfOf, uint256 amount, uint256 index) external returns (bool, uint256);

	function burn(address from, uint256 amount, uint256 index) external returns (uint256);

	function DEBT_TOKEN_REVISION() external view returns (uint256);

	function POOL() external view returns (address);

	function UNDERLYING_ASSET_ADDRESS() external view returns (address);

	function getIncentivesController() external view returns (address);

	function setIncentivesController(address controller) external;
}
