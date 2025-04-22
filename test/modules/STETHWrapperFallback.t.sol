// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {STETHWrapperFallback} from "src/modules/fallbacks/STETHWrapperFallback.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract STETHWrapperFallbackTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override onlyEthereum {
		super.setUp();

		deployVortex(ALICE);

		bytes4[] memory selectors = STETHWrapperFallback.wrapSTETH.selector.bytes4s(
			STETHWrapperFallback.wrapWSTETH.selector,
			STETHWrapperFallback.unwrapWSTETH.selector
		);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE, CALLTYPE_DELEGATE);

		bytes memory installData = encodeModuleParams(
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			""
		);

		ALICE.install(TYPE_FALLBACK, address(aux.stETHWrapper), installData);

		vm.prank(address(ALICE.account));
		STETH.approve(WSTETH.toAddress(), MAX_UINT256);
	}

	function test_immutables() public virtual {
		assertEq(aux.stETHWrapper.STETH(), STETH);
		assertEq(aux.stETHWrapper.WSTETH(), WSTETH);
	}

	function test_wrapSTETH() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		STETHWrapperFallback(address(ALICE.account)).wrapSTETH(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapSTETH_execute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapperFallback.wrapSTETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapSTETH_executeUserOp() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapperFallback.wrapSTETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETH() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		STETHWrapperFallback(address(ALICE.account)).wrapWSTETH(value);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETH_execute() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		bytes memory callData = abi.encodeCall(STETHWrapperFallback.wrapWSTETH, (value));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETH_executeUserOp() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		bytes memory callData = abi.encodeCall(STETHWrapperFallback.wrapWSTETH, (value));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETH() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		STETHWrapperFallback(address(ALICE.account)).unwrapWSTETH(DEFAULT_VALUE);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETH_execute() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapperFallback.unwrapWSTETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETH_executeUserOp() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapperFallback.unwrapWSTETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}
}
