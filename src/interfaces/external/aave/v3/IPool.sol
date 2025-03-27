// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "src/types/Currency.sol";

interface IPool {
	struct ReserveData {
		ReserveConfigurationMap configuration;
		uint128 liquidityIndex;
		uint128 currentLiquidityRate;
		uint128 variableBorrowIndex;
		uint128 currentVariableBorrowRate;
		uint128 currentStableBorrowRate;
		uint40 lastUpdateTimestamp;
		uint16 id;
		Currency aTokenAddress;
		Currency stableDebtTokenAddress;
		Currency variableDebtTokenAddress;
		address interestRateStrategyAddress;
		uint128 accruedToTreasury;
		uint128 unbacked;
		uint128 isolationModeTotalDebt;
	}

	struct ReserveConfigurationMap {
		uint256 data;
	}

	struct UserConfigurationMap {
		uint256 data;
	}

	struct EModeCategory {
		uint16 ltv;
		uint16 liquidationThreshold;
		uint16 liquidationBonus;
		address priceSource;
		string label;
	}

	enum InterestRateMode {
		NONE,
		STABLE,
		VARIABLE
	}

	struct ReserveCache {
		uint256 currScaledVariableDebt;
		uint256 nextScaledVariableDebt;
		uint256 currPrincipalStableDebt;
		uint256 currAvgStableBorrowRate;
		uint256 currTotalStableDebt;
		uint256 nextAvgStableBorrowRate;
		uint256 nextTotalStableDebt;
		uint256 currLiquidityIndex;
		uint256 nextLiquidityIndex;
		uint256 currVariableBorrowIndex;
		uint256 nextVariableBorrowIndex;
		uint256 currLiquidityRate;
		uint256 currVariableBorrowRate;
		uint256 reserveFactor;
		ReserveConfigurationMap reserveConfiguration;
		Currency aTokenAddress;
		Currency stableDebtTokenAddress;
		Currency variableDebtTokenAddress;
		uint40 reserveLastUpdateTimestamp;
		uint40 stableDebtLastUpdateTimestamp;
	}

	struct ExecuteLiquidationCallParams {
		uint256 reservesCount;
		uint256 debtToCover;
		Currency collateralAsset;
		Currency debtAsset;
		address user;
		bool receiveAToken;
		address priceOracle;
		uint8 userEModeCategory;
		address priceOracleSentinel;
	}

	struct ExecuteSupplyParams {
		Currency asset;
		uint256 amount;
		address onBehalfOf;
		uint16 referralCode;
	}

	struct ExecuteBorrowParams {
		Currency asset;
		address user;
		address onBehalfOf;
		uint256 amount;
		InterestRateMode interestRateMode;
		uint16 referralCode;
		bool releaseUnderlying;
		uint256 maxStableRateBorrowSizePercent;
		uint256 reservesCount;
		address oracle;
		uint8 userEModeCategory;
		address priceOracleSentinel;
	}

	struct ExecuteRepayParams {
		Currency asset;
		uint256 amount;
		InterestRateMode interestRateMode;
		address onBehalfOf;
		bool useATokens;
	}

	struct ExecuteWithdrawParams {
		Currency asset;
		uint256 amount;
		address to;
		uint256 reservesCount;
		address oracle;
		uint8 userEModeCategory;
	}

	struct ExecuteSetUserEModeParams {
		uint256 reservesCount;
		address oracle;
		uint8 categoryId;
	}

	struct FinalizeTransferParams {
		Currency asset;
		address from;
		address to;
		uint256 amount;
		uint256 balanceFromBefore;
		uint256 balanceToBefore;
		uint256 reservesCount;
		address oracle;
		uint8 fromEModeCategory;
	}

	struct FlashloanParams {
		address receiverAddress;
		Currency[] assets;
		uint256[] amounts;
		uint256[] interestRateModes;
		address onBehalfOf;
		bytes params;
		uint16 referralCode;
		uint256 flashLoanPremiumToProtocol;
		uint256 flashLoanPremiumTotal;
		uint256 maxStableRateBorrowSizePercent;
		uint256 reservesCount;
		address addressesProvider;
		uint8 userEModeCategory;
		bool isAuthorizedFlashBorrower;
	}

	struct FlashloanSimpleParams {
		address receiverAddress;
		Currency asset;
		uint256 amount;
		bytes params;
		uint16 referralCode;
		uint256 flashLoanPremiumToProtocol;
		uint256 flashLoanPremiumTotal;
	}

	struct FlashLoanRepaymentParams {
		uint256 amount;
		uint256 totalPremium;
		uint256 flashLoanPremiumToProtocol;
		Currency asset;
		address receiverAddress;
		uint16 referralCode;
	}

	struct CalculateUserAccountDataParams {
		UserConfigurationMap userConfig;
		uint256 reservesCount;
		address user;
		address oracle;
		uint8 userEModeCategory;
	}

	struct ValidateBorrowParams {
		ReserveCache reserveCache;
		UserConfigurationMap userConfig;
		Currency asset;
		address userAddress;
		uint256 amount;
		InterestRateMode interestRateMode;
		uint256 maxStableLoanPercent;
		uint256 reservesCount;
		address oracle;
		uint8 userEModeCategory;
		address priceOracleSentinel;
		bool isolationModeActive;
		address isolationModeCollateralAddress;
		uint256 isolationModeDebtCeiling;
	}

	struct ValidateLiquidationCallParams {
		ReserveCache debtReserveCache;
		uint256 totalDebt;
		uint256 healthFactor;
		address priceOracleSentinel;
	}

	struct CalculateInterestRatesParams {
		uint256 unbacked;
		uint256 liquidityAdded;
		uint256 liquidityTaken;
		uint256 totalStableDebt;
		uint256 totalVariableDebt;
		uint256 averageStableBorrowRate;
		uint256 reserveFactor;
		Currency reserve;
		Currency aToken;
	}

	struct InitReserveParams {
		Currency asset;
		Currency aTokenAddress;
		Currency stableDebtAddress;
		Currency variableDebtAddress;
		address interestRateStrategyAddress;
		uint16 reservesCount;
		uint16 maxNumberReserves;
	}

	event MintUnbacked(
		Currency indexed reserve,
		address user,
		address indexed onBehalfOf,
		uint256 amount,
		uint16 indexed referralCode
	);

	event BackUnbacked(Currency indexed reserve, address indexed backer, uint256 amount, uint256 fee);

	event Supply(
		Currency indexed reserve,
		address user,
		address indexed onBehalfOf,
		uint256 amount,
		uint16 indexed referralCode
	);

	event Withdraw(Currency indexed reserve, address indexed user, address indexed to, uint256 amount);

	event Borrow(
		Currency indexed reserve,
		address user,
		address indexed onBehalfOf,
		uint256 amount,
		InterestRateMode interestRateMode,
		uint256 borrowRate,
		uint16 indexed referralCode
	);

	event Repay(
		Currency indexed reserve,
		address indexed user,
		address indexed repayer,
		uint256 amount,
		bool useATokens
	);

	event SwapBorrowRateMode(Currency indexed reserve, address indexed user, InterestRateMode interestRateMode);

	event IsolationModeTotalDebtUpdated(Currency indexed asset, uint256 totalDebt);

	event UserEModeSet(address indexed user, uint8 categoryId);

	event ReserveUsedAsCollateralEnabled(Currency indexed reserve, address indexed user);

	event ReserveUsedAsCollateralDisabled(Currency indexed reserve, address indexed user);

	event RebalanceStableBorrowRate(Currency indexed reserve, address indexed user);

	event FlashLoan(
		address indexed target,
		address initiator,
		Currency indexed asset,
		uint256 amount,
		InterestRateMode interestRateMode,
		uint256 premium,
		uint16 indexed referralCode
	);

	event LiquidationCall(
		Currency indexed collateralAsset,
		Currency indexed debtAsset,
		address indexed user,
		uint256 debtToCover,
		uint256 liquidatedCollateralAmount,
		address liquidator,
		bool receiveAToken
	);

	event ReserveDataUpdated(
		Currency indexed reserve,
		uint256 liquidityRate,
		uint256 stableBorrowRate,
		uint256 variableBorrowRate,
		uint256 liquidityIndex,
		uint256 variableBorrowIndex
	);

	event MintedToTreasury(Currency indexed reserve, uint256 amountMinted);

	function mintUnbacked(Currency asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

	function backUnbacked(Currency asset, uint256 amount, uint256 fee) external;

	function supply(Currency asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

	function supplyWithPermit(
		Currency asset,
		uint256 amount,
		address onBehalfOf,
		uint16 referralCode,
		uint256 deadline,
		uint8 permitV,
		bytes32 permitR,
		bytes32 permitS
	) external;

	function withdraw(Currency asset, uint256 amount, address to) external returns (uint256);

	function borrow(
		Currency asset,
		uint256 amount,
		uint256 interestRateMode,
		uint16 referralCode,
		address onBehalfOf
	) external;

	function repay(
		Currency asset,
		uint256 amount,
		uint256 interestRateMode,
		address onBehalfOf
	) external returns (uint256);

	function repayWithPermit(
		Currency asset,
		uint256 amount,
		uint256 interestRateMode,
		address onBehalfOf,
		uint256 deadline,
		uint8 permitV,
		bytes32 permitR,
		bytes32 permitS
	) external returns (uint256);

	function repayWithATokens(Currency asset, uint256 amount, uint256 interestRateMode) external returns (uint256);

	function swapBorrowRateMode(Currency asset, uint256 interestRateMode) external;

	function rebalanceStableBorrowRate(Currency asset, address user) external;

	function setUserUseReserveAsCollateral(Currency asset, bool useAsCollateral) external;

	function liquidationCall(
		Currency collateralAsset,
		Currency debtAsset,
		address user,
		uint256 debtToCover,
		bool receiveAToken
	) external;

	function flashLoan(
		address receiverAddress,
		Currency[] calldata assets,
		uint256[] calldata amounts,
		uint256[] calldata interestRateModes,
		address onBehalfOf,
		bytes calldata params,
		uint16 referralCode
	) external;

	function flashLoanSimple(
		address receiverAddress,
		Currency asset,
		uint256 amount,
		bytes calldata params,
		uint16 referralCode
	) external;

	function getUserAccountData(
		address user
	)
		external
		view
		returns (
			uint256 totalCollateralBase,
			uint256 totalDebtBase,
			uint256 availableBorrowsBase,
			uint256 currentLiquidationThreshold,
			uint256 ltv,
			uint256 healthFactor
		);

	function initReserve(
		Currency asset,
		Currency aTokenAddress,
		Currency stableDebtAddress,
		Currency variableDebtAddress,
		address interestRateStrategyAddress
	) external;

	function dropReserve(Currency asset) external;

	function setReserveInterestRateStrategyAddress(Currency asset, address rateStrategyAddress) external;

	function setConfiguration(Currency asset, ReserveConfigurationMap calldata configuration) external;

	function getConfiguration(Currency asset) external view returns (ReserveConfigurationMap memory);

	function getUserConfiguration(address user) external view returns (UserConfigurationMap memory);

	function getReserveNormalizedIncome(Currency asset) external view returns (uint256);

	function getReserveNormalizedVariableDebt(Currency asset) external view returns (uint256);

	function getReserveData(Currency asset) external view returns (ReserveData memory);

	function finalizeTransfer(
		Currency asset,
		address from,
		address to,
		uint256 amount,
		uint256 balanceFromBefore,
		uint256 balanceToBefore
	) external;

	function getReservesList() external view returns (Currency[] memory);

	function getReserveAddressById(uint16 id) external view returns (Currency);

	function ADDRESSES_PROVIDER() external view returns (address);

	function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external;

	function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol) external;

	function configureEModeCategory(uint8 id, EModeCategory memory config) external;

	function getEModeCategoryData(uint8 id) external view returns (EModeCategory memory);

	function setUserEMode(uint8 categoryId) external;

	function getUserEMode(address user) external view returns (uint256);

	function resetIsolationModeTotalDebt(address asset) external;

	function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view returns (uint256);

	function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

	function BRIDGE_PROTOCOL_FEE() external view returns (uint256);

	function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);

	function MAX_NUMBER_RESERVES() external view returns (uint16);

	function mintToTreasury(Currency[] calldata assets) external;

	function rescueTokens(Currency token, address to, uint256 amount) external;

	function deposit(Currency asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}
