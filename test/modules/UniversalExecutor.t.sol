// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ExactInputParams, ExactOutputParams, PathKey, PoolKey, PoolId} from "src/interfaces/external/uniswap/v4/V4Types.sol";
import {IHooks} from "src/interfaces/external/uniswap/v4/core/IHooks.sol";
import {IPoolManager} from "src/interfaces/external/uniswap/v4/core/IPoolManager.sol";
import {IV4Quoter} from "src/interfaces/external/uniswap/v4/periphery/IV4Quoter.sol";
import {IStateView} from "src/interfaces/external/uniswap/v4/periphery/IStateView.sol";
import {IUniswapV3Factory as IV3Factory} from "src/interfaces/external/uniswap/v3/core/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "src/interfaces/external/uniswap/v3/core/IUniswapV3Pool.sol";
import {IV3Quoter} from "src/interfaces/external/uniswap/v3/periphery/IV3Quoter.sol";
import {IUniswapV2Factory as IV2Factory} from "src/interfaces/external/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "src/interfaces/external/uniswap/v2/IUniswapV2Pair.sol";
import {IUniversalRouter} from "src/interfaces/external/uniswap/IUniversalRouter.sol";
import {Currency} from "src/types/Currency.sol";
import {ExecType} from "src/types/ExecutionMode.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {PermitSingle} from "test/shared/structs/Protocols.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {ExecutionUtils, Execution} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract UniversalExecutorTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	error InvalidAccountRouter();
	error InvalidPermitParams();
	error InsufficientCallValue();
	error InsufficientAmountIn();
	error InsufficientAmountInMax();
	error InsufficientAmountOut();
	error InsufficientAmountOutMin();

	IPoolManager internal immutable POOL_MANAGER = IPoolManager(getAddress("PoolManager"));
	IV3Factory internal immutable V3_FACTORY = IV3Factory(getAddress("V3Factory"));
	IV2Factory internal immutable V2_FACTORY = IV2Factory(getAddress("V2Factory"));

	IStateView internal immutable STATE_VIEW = IStateView(getAddress("StateView"));
	IV4Quoter internal immutable V4_QUOTER = IV4Quoter(getAddress("V4Quoter"));
	IV3Quoter internal immutable V3_QUOTER = IV3Quoter(getAddress("V3Quoter"));

	address internal immutable UNIVERSAL_ROUTER = getAddress("UniversalRouter");

	bytes4 internal constant APPROVE_SELECTOR = 0x095ea7b3;

	uint256 internal constant PROTOCOL_V4 = 0x04;
	uint256 internal constant PROTOCOL_V3 = 0x03;
	uint256 internal constant PROTOCOL_V2 = 0x02;

	modifier onlyEthereumOrArbitrum() {
		vm.skip(!isEthereum() && !isArbitrum());
		_;
	}

	function setUp() public virtual override {
		super.setUp();

		deployVortex(ALICE);

		ALICE.install(
			TYPE_EXECUTOR,
			address(aux.universalExecutor),
			encodeModuleParams(abi.encodePacked(UNIVERSAL_ROUTER), "")
		);
	}

	function test_immutable() public virtual {
		assertEq(aux.universalExecutor.WRAPPED_NATIVE(), WNATIVE);
	}

	function test_installation() public virtual {
		deployVortex(MURPHY);

		MURPHY.install(
			TYPE_EXECUTOR,
			address(aux.universalExecutor),
			encodeModuleParams(abi.encodePacked(UNIVERSAL_ROUTER), "")
		);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.universalExecutor), ""));
		assertTrue(aux.universalExecutor.isInitialized(address(MURPHY.account)));
		assertEq(aux.universalExecutor.getAccountRouter(address(MURPHY.account)), UNIVERSAL_ROUTER);

		MURPHY.uninstall(TYPE_EXECUTOR, address(aux.universalExecutor), encodeUninstallModuleParams("", ""));

		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.universalExecutor), ""));
		assertFalse(aux.universalExecutor.isInitialized(address(MURPHY.account)));
		assertEq(aux.universalExecutor.getAccountRouter(address(MURPHY.account)), address(0));
	}

	function test_setAccountRouter() public virtual {
		address ROUTER_V1 = mapV1Router();

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		(userOps[0], ) = ALICE.prepareUserOp(
			EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(aux.universalExecutor),
				0,
				abi.encodeCall(UniversalExecutor.setAccountRouter, (ROUTER_V1))
			)
		);

		BUNDLER.handleOps(userOps);
		assertEq(aux.universalExecutor.getAccountRouter(address(ALICE.account)), ROUTER_V1);

		(userOps[0], ) = ALICE.prepareUserOp(
			EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(aux.universalExecutor),
				0,
				abi.encodeCall(UniversalExecutor.setAccountRouter, (UNIVERSAL_ROUTER))
			)
		);

		BUNDLER.handleOps(userOps);
		assertEq(aux.universalExecutor.getAccountRouter(address(ALICE.account)), UNIVERSAL_ROUTER);

		(userOps[0], ) = ALICE.prepareUserOp(
			EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(aux.universalExecutor),
				0,
				abi.encodeCall(UniversalExecutor.setAccountRouter, (address(0)))
			)
		);

		BUNDLER.handleOps(userOps);
		assertEq(aux.universalExecutor.getAccountRouter(address(ALICE.account)), UNIVERSAL_ROUTER);

		vm.prank(address(ALICE.account));
		vm.expectRevert(InvalidAccountRouter.selector);

		aux.universalExecutor.setAccountRouter(address(0));
		assertEq(aux.universalExecutor.getAccountRouter(address(ALICE.account)), UNIVERSAL_ROUTER);
	}

	function test_v4SwapExactInput_singleHop() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(WBTC);
		uint24[] memory fees = FEE_MEDIUM.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_singleHopNativeIn() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = NATIVE.currencies(USDC);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_singleHopNativeOut() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(NATIVE);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_multiHops() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(NATIVE, WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(isEthereum() ? FEE_MEDIUM : FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_multiHopsNativeIn() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = NATIVE.currencies(USDC, WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(FEE_MEDIUM);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_multiHopsNativeOut() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = WBTC.currencies(USDC, NATIVE);
		uint24[] memory fees = FEE_MEDIUM.uint24s(FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_singleHop() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(WBTC);
		uint24[] memory fees = FEE_MEDIUM.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_singleHopNativeIn() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = NATIVE.currencies(USDC);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_singleHopNativeOut() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(NATIVE);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_multiHops() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = USDC.currencies(NATIVE, WBTC);
		uint24[] memory fees = block.chainid == ETHEREUM_CHAIN_ID
			? FEE_LOW.uint24s(FEE_MEDIUM)
			: FEE_LOW.uint24s(FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_multiHopsNativeIn() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = NATIVE.currencies(USDC, WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(FEE_MEDIUM);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactOutput_multiHopsNativeOut() public virtual onlyEthereumOrArbitrum {
		Currency[] memory currencies = WBTC.currencies(USDC, NATIVE);
		uint24[] memory fees = FEE_MEDIUM.uint24s(FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV4ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v4SwapExactInput_revertsWhenInsufficientAmountsGiven()
		public
		virtual
		impersonate(ALICE, true)
		onlyEthereumOrArbitrum
	{
		Currency[] memory currencies = NATIVE.currencies(USDC, WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(FEE_MEDIUM);

		uint256 pathLength = fees.length;
		PathKey[] memory path = new PathKey[](pathLength);

		for (uint256 i; i < pathLength; ++i) {
			PoolKey memory key = toPoolKey(currencies[i], currencies[i + 1], fees[i]);

			path[i] = PathKey({
				intermediateCurrency: currencies[i + 1],
				fee: key.fee,
				tickSpacing: key.tickSpacing,
				hooks: key.hooks,
				hookData: ""
			});
		}

		uint256 amountIn = deriveAmount(currencies[0]);

		(uint256 amountOutMin, ) = V4_QUOTER.quoteExactInput(
			IV4Quoter.QuoteExactParams({exactCurrency: currencies[0], path: path, exactAmount: uint128(amountIn)})
		);

		deal(address(ALICE.account), amountIn);

		bytes memory swapParams = abi.encode(
			ExactInputParams({currencyIn: currencies[0], path: path, amountIn: uint128(0), amountOutMin: uint128(0)})
		);

		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountIn.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));

		swapParams = abi.encode(
			ExactInputParams({
				currencyIn: currencies[0],
				path: path,
				amountIn: uint128(amountIn),
				amountOutMin: uint128(0)
			})
		);

		vm.expectRevert(InsufficientAmountOutMin.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));

		swapParams = abi.encode(
			ExactInputParams({
				currencyIn: currencies[0],
				path: path,
				amountIn: uint128(amountIn),
				amountOutMin: uint128(amountOutMin)
			})
		);

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactInput{value: amountIn / 2}(
			encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE)
		);

		swapParams = abi.encode(
			ExactInputParams({
				currencyIn: WNATIVE,
				path: path,
				amountIn: uint128(amountIn),
				amountOutMin: uint128(amountOutMin)
			})
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));
	}

	function test_v4SwapExactOutput_revertsWhenInsufficientAmountsGiven()
		public
		virtual
		impersonate(ALICE, true)
		onlyEthereumOrArbitrum
	{
		Currency[] memory currencies = NATIVE.currencies(USDC, WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(FEE_MEDIUM);

		uint256 pathLength = fees.length;
		PathKey[] memory path = new PathKey[](pathLength);

		for (uint256 i = pathLength; i > 0; --i) {
			PoolKey memory key = toPoolKey(currencies[i - 1], currencies[i], fees[i - 1]);

			path[i - 1] = PathKey({
				intermediateCurrency: currencies[i - 1],
				fee: key.fee,
				tickSpacing: key.tickSpacing,
				hooks: key.hooks,
				hookData: ""
			});
		}

		uint256 amountOut = deriveAmount(currencies[pathLength]);

		(uint256 amountInMax, ) = V4_QUOTER.quoteExactOutput(
			IV4Quoter.QuoteExactParams({
				exactCurrency: currencies[pathLength],
				path: path,
				exactAmount: uint128(amountOut)
			})
		);

		deal(address(ALICE.account), amountInMax);

		bytes memory swapParams = abi.encode(
			ExactOutputParams({
				currencyOut: currencies[pathLength],
				path: path,
				amountOut: uint128(0),
				amountInMax: uint128(0)
			})
		);

		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountOut.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));

		swapParams = abi.encode(
			ExactOutputParams({
				currencyOut: currencies[pathLength],
				path: path,
				amountOut: uint128(amountOut),
				amountInMax: uint128(0)
			})
		);

		vm.expectRevert(InsufficientAmountInMax.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));

		swapParams = abi.encode(
			ExactOutputParams({
				currencyOut: currencies[pathLength],
				path: path,
				amountOut: uint128(amountOut),
				amountInMax: uint128(amountInMax)
			})
		);

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactOutput{value: amountInMax / 2}(
			encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE)
		);

		path[0] = PathKey({
			intermediateCurrency: WNATIVE,
			fee: path[0].fee,
			tickSpacing: path[0].tickSpacing,
			hooks: path[0].hooks,
			hookData: ""
		});

		swapParams = abi.encode(
			ExactOutputParams({
				currencyOut: currencies[pathLength],
				path: path,
				amountOut: uint128(amountOut),
				amountInMax: uint128(amountInMax)
			})
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, DEADLINE));
	}

	function test_v3SwapExactInput_singleHop() public virtual {
		Currency[] memory currencies = USDC.currencies(isPolygon() ? USDCe : USDT);
		uint24[] memory fees = FEE_LOWEST.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_singleHopNativeIn() public virtual {
		Currency[] memory currencies = WNATIVE.currencies(isPolygon() ? USDCe : USDC);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_singleHopNativeOut() public virtual {
		Currency[] memory currencies = (isPolygon() ? USDCe : USDC).currencies(WNATIVE);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_multiHops() public virtual {
		Currency[] memory currencies = (isPolygon() ? USDCe : USDC).currencies(WETH, isBase() ? CBBTC : WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_multiHopsNativeIn() public virtual {
		Currency[] memory currencies = WNATIVE.currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			isBase() ? CBBTC : WBTC
		);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_multiHopsNativeOut() public virtual {
		Currency[] memory currencies = (isBase() ? CBBTC : WBTC).currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			WNATIVE
		);
		uint24[] memory fees = (isOptimism() ? FEE_MEDIUM : FEE_LOW).uint24s(FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactInput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_singleHop() public virtual {
		Currency[] memory currencies = (isPolygon() ? USDCe : isArbitrum() ? USDT : USDC).currencies(
			isBase() ? CBBTC : WBTC
		);
		uint24[] memory fees = (isOptimism() ? FEE_MEDIUM : FEE_LOW).uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_singleHopNativeIn() public virtual {
		Currency[] memory currencies = WNATIVE.currencies(isPolygon() ? USDCe : USDC);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_singleHopNativeOut() public virtual {
		Currency[] memory currencies = (isPolygon() ? USDCe : USDC).currencies(WNATIVE);
		uint24[] memory fees = FEE_LOW.uint24s();

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_multiHops() public virtual {
		Currency[] memory currencies = (isPolygon() ? USDCe : USDC).currencies(WETH, isBase() ? CBBTC : WBTC);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_multiHopsNativeIn() public virtual {
		Currency[] memory currencies = WNATIVE.currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			isBase() ? CBBTC : WBTC
		);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactOutput_multiHopsNativeOut() public virtual {
		Currency[] memory currencies = (isBase() ? CBBTC : WBTC).currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			WNATIVE
		);
		uint24[] memory fees = (isOptimism() ? FEE_MEDIUM : FEE_LOW).uint24s(FEE_LOW);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV3ExactOutput(
			ALICE,
			currencies,
			fees,
			DEADLINE
		);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v3SwapExactInput_revertsWhenInsufficientAmountsGiven() public virtual impersonate(ALICE, true) {
		Currency[] memory currencies = WNATIVE.currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			isBase() ? CBBTC : WBTC
		);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		uint256 pathLength = fees.length;
		bytes memory path = abi.encodePacked(currencies[0]);

		for (uint256 i; i < pathLength; ++i) {
			path = abi.encodePacked(path, fees[i], currencies[i + 1]);
		}

		uint256 amountIn = deriveAmount(currencies[0]);
		(uint256 amountOutMin, , , ) = V3_QUOTER.quoteExactInput(path, amountIn);

		deal(address(ALICE.account), amountIn);

		bytes memory swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(0), uint128(0));

		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountIn.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(amountIn), uint128(0));

		vm.expectRevert(InsufficientAmountOutMin.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(amountIn), uint128(amountOutMin));

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactInput{value: amountIn / 2}(
			encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE)
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));
	}

	function test_v3SwapExactOutput_revertsWhenInsufficientAmountsGiven() public virtual impersonate(ALICE, true) {
		Currency[] memory currencies = WNATIVE.currencies(
			isPolygon() ? USDCe : isArbitrum() ? USDT : USDC,
			isBase() ? CBBTC : WBTC
		);
		uint24[] memory fees = FEE_LOW.uint24s(isOptimism() ? FEE_MEDIUM : FEE_LOW);

		uint256 pathLength = fees.length;
		bytes memory path = abi.encodePacked(currencies[pathLength]);

		for (uint256 i = pathLength; i > 0; --i) {
			path = abi.encodePacked(path, fees[i - 1], currencies[i - 1]);
		}

		uint256 amountOut = deriveAmount(currencies[pathLength]);
		(uint256 amountInMax, , , ) = V3_QUOTER.quoteExactOutput(path, amountOut);

		deal(address(ALICE.account), amountInMax);

		bytes memory swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(0), uint128(0));

		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountOut.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(amountOut), uint128(0));

		vm.expectRevert(InsufficientAmountInMax.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(bytes4(uint32(path.length)), path, uint128(amountOut), uint128(amountInMax));

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactOutput{value: amountInMax / 2}(
			encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE)
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, DEADLINE));
	}

	function test_v2SwapExactInput_singleHop() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(USDT);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_singleHopNativeIn() public virtual onlyEthereum {
		Currency[] memory currencies = WNATIVE.currencies(USDC);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_singleHopNativeOut() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(WNATIVE);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_multiHops() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(WNATIVE, WBTC);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_multiHopsNativeIn() public virtual onlyEthereum {
		Currency[] memory currencies = WNATIVE.currencies(USDC, WBTC);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_multiHopsNativeOut() public virtual onlyEthereum {
		Currency[] memory currencies = USDT.currencies(USDC, WNATIVE);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactInput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, true);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_singleHop() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(USDT);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_singleHopNativeIn() public virtual onlyEthereum {
		Currency[] memory currencies = WNATIVE.currencies(WBTC);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_singleHopNativeOut() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(WNATIVE);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertGe(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_multiHops() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(WNATIVE, WBTC);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_multiHopsNativeIn() public virtual onlyEthereum {
		Currency[] memory currencies = WNATIVE.currencies(USDC, USDT);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, amountIn, false);

		assertEq(balanceIn, amountIn);
		assertEq(balanceOut, amountOut);
	}

	function test_v2SwapExactOutput_multiHopsNativeOut() public virtual onlyEthereum {
		Currency[] memory currencies = USDC.currencies(USDT, WNATIVE);

		(bytes memory params, uint256 amountIn, uint256 amountOut) = prepareV2ExactOutput(ALICE, currencies, DEADLINE);

		(uint256 balanceIn, uint256 balanceOut) = performSwap(ALICE, currencies, params, 0, false);

		assertEq(balanceIn, amountIn);
		assertGe(balanceOut, amountOut);
	}

	function test_v2SwapExactInput_revertsWhenInsufficientAmountsGiven()
		public
		virtual
		impersonate(ALICE, true)
		onlyEthereum
	{
		Currency[] memory currencies = WNATIVE.currencies(USDC, WBTC);

		uint256 amountIn = deriveAmount(currencies[0]);
		uint256 amountOutMin = amountIn;

		for (uint256 i; i < currencies.length - 1; ++i) {
			IUniswapV2Pair pair = V2_FACTORY.getPair(currencies[i], currencies[i + 1]);

			(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

			(uint256 reserveIn, uint256 reserveOut) = currencies[i] < currencies[i + 1]
				? (reserve0, reserve1)
				: (reserve1, reserve0);

			uint256 amountInWithFee = amountOutMin * 997;
			uint256 numerator = amountInWithFee * reserveOut;
			uint256 denominator = (reserveIn * 1000) + amountInWithFee;

			amountOutMin = numerator / denominator;
		}

		deal(address(ALICE.account), amountIn);

		bytes memory swapParams = abi.encodePacked(abi.encode(currencies), uint128(0), uint128(0));
		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountIn.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountIn), uint128(0));

		vm.expectRevert(InsufficientAmountOutMin.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountIn), uint128(amountOutMin));

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactInput{value: amountIn / 2}(
			encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE)
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactInput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));
	}

	function test_v2SwapExactOutput_revertsWhenInsufficientAmountsGiven()
		public
		virtual
		impersonate(ALICE, true)
		onlyEthereum
	{
		Currency[] memory currencies = WNATIVE.currencies(USDC, USDT);

		uint256 amountOut = deriveAmount(currencies[currencies.length - 1]);
		uint256 amountInMax = amountOut;

		for (uint256 i = currencies.length - 1; i > 0; --i) {
			IUniswapV2Pair pair = V2_FACTORY.getPair(currencies[i - 1], currencies[i]);

			(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

			(uint256 reserveIn, uint256 reserveOut) = currencies[i - 1] < currencies[i]
				? (reserve0, reserve1)
				: (reserve1, reserve0);

			uint256 numerator = reserveIn * amountInMax * 1000;
			uint256 denominator = (reserveOut - amountInMax) * 997;

			amountInMax = (numerator / denominator) + 1;
		}

		deal(address(ALICE.account), amountInMax);

		bytes memory swapParams = abi.encodePacked(abi.encode(currencies), uint128(0), uint128(0));
		bytes memory permitParams;

		vm.expectRevert(InsufficientAmountOut.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountOut), uint128(0));

		vm.expectRevert(InsufficientAmountInMax.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));

		swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountOut), uint128(amountInMax));

		vm.expectRevert(InsufficientCallValue.selector);
		aux.universalExecutor.swapExactOutput{value: amountInMax / 2}(
			encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE)
		);

		vm.expectRevert(InvalidPermitParams.selector);
		aux.universalExecutor.swapExactOutput(encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, DEADLINE));
	}

	function performSwap(
		Signer memory signer,
		Currency[] memory currencies,
		bytes memory params,
		uint256 value,
		bool isExactIn
	) internal virtual returns (uint256 balanceIn, uint256 balanceOut) {
		(Currency currencyIn, Currency currencyOut) = uint8(bytes1(params)) != PROTOCOL_V4
			? (unwrapCurrency(currencies[0]), unwrapCurrency(currencies[currencies.length - 1]))
			: (currencies[0], currencies[currencies.length - 1]);

		bytes memory callData = isExactIn
			? abi.encodeCall(UniversalExecutor.swapExactInput, (params))
			: abi.encodeCall(UniversalExecutor.swapExactOutput, (params));

		bytes memory executionCalldata;

		if (!currencyIn.isZero() && currencyIn.allowance(address(signer.account), address(PERMIT2)) != MAX_UINT256) {
			Execution[] memory executions = new Execution[](2);

			executions[0] = Execution({
				target: currencyIn.toAddress(),
				value: 0,
				callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
			});

			executions[1] = Execution({target: address(aux.universalExecutor), value: value, callData: callData});

			executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(executions);
		} else {
			executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(aux.universalExecutor),
				value,
				callData
			);
		}

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(executionCalldata);

		balanceIn = currencyIn.balanceOf(address(signer.account));
		balanceOut = currencyOut.balanceOf(address(signer.account));

		BUNDLER.handleOps(userOps);

		balanceIn = balanceIn - currencyIn.balanceOf(address(signer.account));
		balanceOut = currencyOut.balanceOf(address(signer.account)) - balanceOut;

		assertEq(UNIVERSAL_ROUTER.balance, 0);

		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].balanceOf(UNIVERSAL_ROUTER), 0);
		}
	}

	function prepareV4ExactInput(
		Signer memory signer,
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		uint256 pathLength = fees.length;
		assertEq(pathLength, currencies.length - 1);

		PathKey[] memory path = new PathKey[](pathLength);
		PoolKey memory key;
		PoolId id;

		for (uint256 i; i < pathLength; ++i) {
			id = (key = toPoolKey(currencies[i], currencies[i + 1], fees[i])).toId();

			(uint160 sqrtPriceX96, , , ) = STATE_VIEW.getSlot0(id);
			assertTrue(sqrtPriceX96 != 0, "pool not initialized");
			assertTrue(STATE_VIEW.getLiquidity(id) != 0, "insufficient liquidity");

			path[i] = PathKey({
				intermediateCurrency: currencies[i + 1],
				fee: key.fee,
				tickSpacing: key.tickSpacing,
				hooks: key.hooks,
				hookData: ""
			});
		}

		IV4Quoter.QuoteExactParams memory quoteParams = IV4Quoter.QuoteExactParams({
			exactCurrency: currencies[0],
			path: path,
			exactAmount: uint128(amountIn = deriveAmount(currencies[0]))
		});

		(amountOut, ) = V4_QUOTER.quoteExactInput(quoteParams);

		bytes memory swapParams = abi.encode(
			ExactInputParams({
				currencyIn: currencies[0],
				path: path,
				amountIn: uint128(amountIn),
				amountOutMin: uint128(amountOut)
			})
		);
		bytes memory permitParams;

		if (!currencies[0].isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencies[0],
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, deadline);

		deal(currencies[0], address(signer.account), amountIn);
	}

	function prepareV4ExactOutput(
		Signer memory signer,
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		uint256 pathLength = fees.length;
		assertEq(pathLength, currencies.length - 1);

		PathKey[] memory path = new PathKey[](pathLength);
		PoolKey memory key;
		PoolId id;

		for (uint256 i = pathLength; i > 0; --i) {
			id = (key = toPoolKey(currencies[i - 1], currencies[i], fees[i - 1])).toId();

			(uint160 sqrtPriceX96, , , ) = STATE_VIEW.getSlot0(id);
			assertTrue(sqrtPriceX96 != 0, "pool not initialized");
			assertTrue(STATE_VIEW.getLiquidity(id) != 0, "insufficient liquidity");

			path[i - 1] = PathKey({
				intermediateCurrency: currencies[i - 1],
				fee: key.fee,
				tickSpacing: key.tickSpacing,
				hooks: key.hooks,
				hookData: ""
			});
		}

		IV4Quoter.QuoteExactParams memory quoteParams = IV4Quoter.QuoteExactParams({
			exactCurrency: currencies[pathLength],
			path: path,
			exactAmount: uint128(amountOut = deriveAmount(currencies[pathLength]))
		});

		(amountIn, ) = V4_QUOTER.quoteExactOutput(quoteParams);

		bytes memory swapParams = abi.encode(
			ExactOutputParams({
				currencyOut: currencies[pathLength],
				path: path,
				amountOut: uint128(amountOut),
				amountInMax: uint128(amountIn)
			})
		);
		bytes memory permitParams;

		if (!currencies[0].isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencies[0],
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V4, swapParams, permitParams, deadline);

		deal(currencies[0], address(signer.account), amountIn);
	}

	function prepareV3ExactInput(
		Signer memory signer,
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		uint256 pathLength = fees.length;
		assertEq(pathLength, currencies.length - 1);

		bytes memory path = abi.encodePacked(currencies[0]);

		for (uint256 i; i < pathLength; ++i) {
			IUniswapV3Pool pool = V3_FACTORY.getPool(currencies[i], currencies[i + 1], fees[i]);
			assertTrue(address(pool).code.length != 0, "pool not exists");

			(uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
			assertTrue(sqrtPriceX96 != 0, "pool not initialized");
			assertTrue(pool.liquidity() != 0, "insufficient liquidity");

			path = abi.encodePacked(path, fees[i], currencies[i + 1]);
		}

		(amountOut, , , ) = V3_QUOTER.quoteExactInput(path, (amountIn = deriveAmount(currencies[0])));

		bytes memory swapParams = abi.encodePacked(
			bytes4(uint32(path.length)),
			path,
			uint128(amountIn),
			uint128(amountOut)
		);
		bytes memory permitParams;

		Currency currencyIn = unwrapCurrency(currencies[0]);
		if (!currencyIn.isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencyIn,
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, deadline);

		deal(currencyIn, address(signer.account), amountIn);
	}

	function prepareV3ExactOutput(
		Signer memory signer,
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		uint256 pathLength = fees.length;
		assertEq(pathLength, currencies.length - 1);

		bytes memory path = abi.encodePacked(currencies[pathLength]);

		for (uint256 i = pathLength; i > 0; --i) {
			IUniswapV3Pool pool = V3_FACTORY.getPool(currencies[i - 1], currencies[i], fees[i - 1]);
			assertTrue(address(pool).code.length != 0, "pool not exists");

			(uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
			assertTrue(sqrtPriceX96 != 0, "pool not initialized");
			assertTrue(pool.liquidity() != 0, "insufficient liquidity");

			path = abi.encodePacked(path, fees[i - 1], currencies[i - 1]);
		}

		(amountIn, , , ) = V3_QUOTER.quoteExactOutput(path, (amountOut = deriveAmount(currencies[pathLength])));

		bytes memory swapParams = abi.encodePacked(
			bytes4(uint32(path.length)),
			path,
			uint128(amountOut),
			uint128(amountIn)
		);
		bytes memory permitParams;

		Currency currencyIn = unwrapCurrency(currencies[0]);
		if (!currencyIn.isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencyIn,
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V3, swapParams, permitParams, deadline);

		deal(currencyIn, address(signer.account), amountIn);
	}

	function prepareV2ExactInput(
		Signer memory signer,
		Currency[] memory currencies,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		assertGe(currencies.length, 2);
		amountOut = amountIn = deriveAmount(currencies[0]);

		for (uint256 i; i < currencies.length - 1; ++i) {
			IUniswapV2Pair pair = V2_FACTORY.getPair(currencies[i], currencies[i + 1]);
			assertTrue(address(pair).code.length != 0, "pair not exists");

			(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
			assertTrue(reserve0 != 0 && reserve1 != 0, "insufficient liquidity");

			(uint256 reserveIn, uint256 reserveOut) = currencies[i] < currencies[i + 1]
				? (reserve0, reserve1)
				: (reserve1, reserve0);

			uint256 amountInWithFee = amountOut * 997;
			uint256 numerator = amountInWithFee * reserveOut;
			uint256 denominator = (reserveIn * 1000) + amountInWithFee;

			amountOut = numerator / denominator;
		}

		bytes memory swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountIn), uint128(amountOut));
		bytes memory permitParams;

		Currency currencyIn = unwrapCurrency(currencies[0]);
		if (!currencyIn.isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencyIn,
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, deadline);

		deal(currencyIn, address(signer.account), amountIn);
	}

	function prepareV2ExactOutput(
		Signer memory signer,
		Currency[] memory currencies,
		uint256 deadline
	) internal virtual returns (bytes memory params, uint256 amountIn, uint256 amountOut) {
		assertGe(currencies.length, 2);
		amountIn = amountOut = deriveAmount(currencies[currencies.length - 1]);

		for (uint256 i = currencies.length - 1; i > 0; --i) {
			IUniswapV2Pair pair = V2_FACTORY.getPair(currencies[i - 1], currencies[i]);
			assertTrue(address(pair).code.length != 0, "pair not exists");

			(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
			assertTrue(reserve0 != 0 && reserve1 != 0, "insufficient liquidity");

			(uint256 reserveIn, uint256 reserveOut) = currencies[i - 1] < currencies[i]
				? (reserve0, reserve1)
				: (reserve1, reserve0);

			uint256 numerator = reserveIn * amountIn * 1000;
			uint256 denominator = (reserveOut - amountIn) * 997;

			amountIn = (numerator / denominator) + 1;
		}

		bytes memory swapParams = abi.encodePacked(abi.encode(currencies), uint128(amountOut), uint128(amountIn));
		bytes memory permitParams;

		Currency currencyIn = unwrapCurrency(currencies[0]);
		if (!currencyIn.isZero()) {
			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(
				signer,
				currencyIn,
				UNIVERSAL_ROUTER
			);

			permitParams = abi.encode(permit, signature);
		}

		params = encodeSwapParams(PROTOCOL_V2, swapParams, permitParams, deadline);

		deal(currencyIn, address(signer.account), amountIn);
	}

	function mapV1Router() internal view virtual returns (address router) {
		assembly ("memory-safe") {
			switch chainid()
			case 10 {
				router := 0xb555edF5dcF85f42cEeF1f3630a52A108E55A654
			}
			case 137 {
				router := 0x4C60051384bd2d3C01bfc845Cf5F4b44bcbE9de5
			}
			case 8453 {
				router := 0xeC8B0F7Ffe3ae75d7FfAb09429e3675bb63503e4
			}
			case 42161 {
				router := 0x4C60051384bd2d3C01bfc845Cf5F4b44bcbE9de5
			}
			default {
				router := 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B
			}
		}
	}

	function wrapCurrency(Currency currency) internal view virtual returns (Currency) {
		return currency.isZero() ? WNATIVE : currency;
	}

	function unwrapCurrency(Currency currency) internal view virtual returns (Currency) {
		return currency == WNATIVE ? NATIVE : currency;
	}

	function deriveAmount(Currency currency) internal view virtual returns (uint256 amount) {
		if (currency.isZero() || currency == WNATIVE || currency == WSTETH) {
			amount = 10 ether;
		} else if (currency == WBTC || currency == CBBTC) {
			amount = 1e8;
		} else if (currency == USDC || currency == USDCe || currency == USDT) {
			amount = 100000e6;
		} else {
			uint256 scale = 10 ** currency.decimals();
			amount = 10 * scale;
		}
	}

	function deriveTickSpacing(uint24 fee) internal pure virtual returns (int24 tickSpacing) {
		assembly ("memory-safe") {
			switch fee
			case 100 {
				tickSpacing := 1
			}
			default {
				tickSpacing := div(fee, 50)
			}
		}
	}

	function encodeSwapParams(
		uint256 protocol,
		bytes memory swapParams,
		bytes memory permitParams,
		uint256 deadline
	) internal pure virtual returns (bytes memory params) {
		params = abi.encodePacked(
			bytes1(uint8(protocol)),
			bytes4(uint32(swapParams.length)),
			swapParams,
			bytes4(uint32(permitParams.length)),
			permitParams,
			uint40(deadline)
		);
	}

	function toPoolKey(
		Currency currency0,
		Currency currency1,
		uint24 fee
	) internal pure virtual returns (PoolKey memory key) {
		if (currency0 > currency1) (currency0, currency1) = (currency1, currency0);

		key = PoolKey({
			currency0: currency0,
			currency1: currency1,
			fee: fee,
			tickSpacing: deriveTickSpacing(fee),
			hooks: IHooks(address(0))
		});
	}
}
