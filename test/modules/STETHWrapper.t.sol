// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";

contract STETHWrapperTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override onlyEthereum {
		super.setUp();

		deployVortex(ALICE, 0, INITIAL_VALUE, address(VORTEX_FACTORY), true);

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

	function test_wrapSTETH() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		STETHWrapper(payable(address(ALICE.account))).wrapSTETH(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapSTETHByExecute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.wrapSTETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapSTETHByExecuteUserOp() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.wrapSTETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(address(ALICE.account).balance, 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETH() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		STETHWrapper(payable(address(ALICE.account))).wrapWSTETH(value);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETHByExecute() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		bytes memory callData = abi.encodeCall(STETHWrapper.wrapWSTETH, (value));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_wrapWSTETHByExecuteUserOp() public virtual {
		deal(STETH, address(ALICE.account), DEFAULT_VALUE);
		assertGe(STETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);

		uint256 value = STETH.balanceOf(address(ALICE.account));
		bytes memory callData = abi.encodeCall(STETHWrapper.wrapWSTETH, (value));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertLt(STETH.balanceOf(address(ALICE.account)), value);
		assertGt(WSTETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETH() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		STETHWrapper(payable(address(ALICE.account))).unwrapWSTETH(DEFAULT_VALUE);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETHByExecute() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.unwrapWSTETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}

	function test_unwrapWSTETHByExecuteUserOp() public virtual {
		deal(WSTETH, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WSTETH.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(STETH.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(STETHWrapper.unwrapWSTETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(WSTETH.balanceOf(address(ALICE.account)), 0);
		assertGt(STETH.balanceOf(address(ALICE.account)), 0);
	}
}
