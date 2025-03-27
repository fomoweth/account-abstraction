// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";

contract NativeWrapperTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override {
		super.setUp();

		deployVortex(ALICE, 0, INITIAL_VALUE, address(VORTEX_FACTORY), true);

		bytes4[] memory selectors = NativeWrapper.wrapETH.selector.bytes4s(NativeWrapper.unwrapWETH.selector);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE);

		bytes memory installData = encodeInstallModuleData(
			TYPE_FALLBACK.moduleTypes(),
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			""
		);

		ALICE.install(TYPE_FALLBACK, address(NATIVE_WRAPPER), installData);
	}

	function test_wrapETH() public virtual impersonate(address(ALICE.account)) {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		NativeWrapper(payable(address(ALICE.account))).wrapETH(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrapETHByExecute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.wrapETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrapETHByExecuteUserOp() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.wrapETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_unwrapWETH() public virtual impersonate(address(ALICE.account)) {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		NativeWrapper(payable(address(ALICE.account))).unwrapWETH(DEFAULT_VALUE);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrapWETHByExecute() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.unwrapWETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrapWETHByExecuteUserOp() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.unwrapWETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		ENTRYPOINT.handleOps(userOps, ALICE.eoa);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}
}
