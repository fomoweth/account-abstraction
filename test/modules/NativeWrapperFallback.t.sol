// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract NativeWrapperFallbackTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	function setUp() public virtual override {
		super.setUp();

		deployVortex(ALICE);

		bytes4[] memory selectors = NativeWrapperFallback.wrap.selector.bytes4s(NativeWrapperFallback.unwrap.selector);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE);

		bytes memory installData = encodeModuleParams(
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			""
		);

		ALICE.install(TYPE_FALLBACK, address(aux.nativeWrapper), installData);
	}

	function test_immutable() public virtual {
		assertEq(aux.nativeWrapper.WRAPPED_NATIVE(), WNATIVE);
	}

	function test_wrap() public virtual impersonate(ALICE, true) {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		NativeWrapperFallback(address(ALICE.account)).wrap(DEFAULT_VALUE);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrap_execute() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapperFallback.wrap, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_wrap_executeUserOp() public virtual {
		deal(address(ALICE.account), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		bytes memory callData = abi.encodeCall(NativeWrapperFallback.wrap, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(address(ALICE.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
	}

	function test_unwrap() public virtual impersonate(ALICE, true) {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		NativeWrapperFallback(address(ALICE.account)).unwrap(DEFAULT_VALUE);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrap_execute() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapperFallback.unwrap, (DEFAULT_VALUE));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(ALICE.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}

	function test_unwrap_executeUserOp() public virtual {
		deal(WNATIVE, address(ALICE.account), DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), DEFAULT_VALUE);
		assertEq(address(ALICE.account).balance, 0);

		bytes memory callData = abi.encodeCall(NativeWrapperFallback.unwrap, (DEFAULT_VALUE));
		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);
		assertEq(address(ALICE.account).balance, DEFAULT_VALUE);
	}
}
