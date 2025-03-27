// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";

interface IAToken is IERC20Metadata, IERC20Permit, IScaledBalanceToken {
	event Mint(
		address indexed caller,
		address indexed onBehalfOf,
		uint256 value,
		uint256 balanceIncrease,
		uint256 index
	);

	event Burn(address indexed from, address indexed target, uint256 value, uint256 balanceIncrease, uint256 index);

	// IDelegationToken

	function delegate(address delegatee) external;

	// IInitializableAToken

	event Initialized(
		address indexed underlyingAsset,
		address indexed pool,
		address treasury,
		address incentivesController,
		uint8 aTokenDecimals,
		string aTokenName,
		string aTokenSymbol,
		bytes params
	);

	function initialize(
		address pool,
		address treasury,
		address underlyingAsset,
		address incentivesController,
		uint8 aTokenDecimals,
		string calldata aTokenName,
		string calldata aTokenSymbol,
		bytes calldata params
	) external;

	// IAToken

	event BalanceTransfer(address indexed from, address indexed to, uint256 value, uint256 index);

	function mint(address caller, address onBehalfOf, uint256 amount, uint256 index) external returns (bool);

	function burn(address from, address receiverOfUnderlying, uint256 amount, uint256 index) external;

	function mintToTreasury(uint256 amount, uint256 index) external;

	function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

	function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

	function transferOnLiquidation(address from, address to, uint256 value) external;

	function transferUnderlyingTo(address target, uint256 amount) external;

	function handleRepayment(address user, address onBehalfOf, uint256 amount) external;

	function ATOKEN_REVISION() external view returns (uint256);

	function POOL() external view returns (address);

	function UNDERLYING_ASSET_ADDRESS() external view returns (address);

	function RESERVE_TREASURY_ADDRESS() external view returns (address);

	function getIncentivesController() external view returns (address);

	function setIncentivesController(address controller) external;

	function rescueTokens(address token, address to, uint256 amount) external;

	// IDelegationAwareAToken

	event DelegateUnderlyingTo(address indexed delegatee);

	function delegateUnderlyingTo(address delegatee) external;
}
