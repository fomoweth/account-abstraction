// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract STETHWrapperTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override onlyEthereum {
		super.setUp();

		deployVortex(ALICE, 0, INITIAL_VALUE, address(K1_FACTORY), true);

		bytes4[] memory selectors = STETHWrapper.wrapSTETH.selector.bytes4s(
			STETHWrapper.wrapWSTETH.selector,
			STETHWrapper.unwrapWSTETH.selector
		);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE, CALLTYPE_DELEGATE);

		bytes memory installData = encodeInstallModuleParams(
			TYPE_FALLBACK.moduleTypes(),
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			""
		);

		ALICE.install(TYPE_FALLBACK, address(STETH_WRAPPER), installData);

		vm.prank(address(ALICE.account));
		STETH.approve(WSTETH.toAddress(), MAX_UINT256);
	}

	function test_immutables() public virtual {
		assertEq(STETH_WRAPPER.STETH(), STETH);
		assertEq(STETH_WRAPPER.WSTETH(), WSTETH);
	}

	function test_wrapSTETH() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		STETHWrapper(address(ALICE.account)).wrapSTETH(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapSTETH_execute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.wrapSTETH, (DEFAULT_VALUE));
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

		bytes memory callData = abi.encodeCall(STETHWrapper.wrapSTETH, (DEFAULT_VALUE));
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
		STETHWrapper(address(ALICE.account)).wrapWSTETH(value);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETH_execute() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		bytes memory callData = abi.encodeCall(STETHWrapper.wrapWSTETH, (value));
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
		bytes memory callData = abi.encodeCall(STETHWrapper.wrapWSTETH, (value));
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

		STETHWrapper(address(ALICE.account)).unwrapWSTETH(DEFAULT_VALUE);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETH_execute() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.unwrapWSTETH, (DEFAULT_VALUE));
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

		bytes memory callData = abi.encodeCall(STETHWrapper.unwrapWSTETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}
}
