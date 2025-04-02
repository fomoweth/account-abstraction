// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract NativeWrapperTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override {
		super.setUp();

		deployVortex(ALICE, 0, INITIAL_VALUE, address(K1_FACTORY), true);

		bytes4[] memory selectors = NativeWrapper.wrapETH.selector.bytes4s(NativeWrapper.unwrapWETH.selector);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE);

		bytes memory installData = encodeInstallModuleParams(
			TYPE_FALLBACK.moduleTypes(),
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			""
		);

		ALICE.install(TYPE_FALLBACK, address(NATIVE_WRAPPER), installData);
	}

	function test_immutable() public virtual {
		assertEq(NATIVE_WRAPPER.WRAPPED_NATIVE(), WNATIVE);
	}

	function test_wrapETH() public virtual impersonate(ALICE, true) {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		NativeWrapper(address(ALICE.account)).wrapETH(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrapETH_execute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.wrapETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrapETH_executeUserOp() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.wrapETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(VORTEX.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_unwrapWETH() public virtual impersonate(ALICE, true) {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		NativeWrapper(address(ALICE.account)).unwrapWETH(DEFAULT_VALUE);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrapWETH_execute() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.unwrapWETH, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrapWETH_executeUserOp() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapper.unwrapWETH, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(VORTEX.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}
}
