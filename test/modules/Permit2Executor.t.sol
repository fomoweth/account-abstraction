// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console2 as console} from "forge-std/Test.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Currency} from "src/types/Currency.sol";
import {ExecType} from "src/types/ExecutionMode.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {PermitDetails, PermitSingle, PermitBatch} from "test/shared/structs/Protocols.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {ExecutionUtils, Execution} from "test/shared/utils/ExecutionUtils.sol";

contract Permit2ExecutorTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	error InvalidContractSignature();

	bytes4 internal constant APPROVE_SELECTOR = 0x095ea7b3;

	address internal immutable spender = makeAddr("SPENDER");

	Currency[] internal currencies;

	function setUp() public virtual override {
		super.setUp();

		currencies = WNATIVE.currencies(WSTETH, USDC, DAI);

		deployVortex(ALICE, 0, INITIAL_VALUE, address(VORTEX_FACTORY), true);

		ALICE.install(
			TYPE_EXECUTOR,
			address(PERMIT2_EXECUTOR),
			encodeInstallModuleParams(TYPE_EXECUTOR.moduleTypes(), "", "")
		);
	}

	function test_approveCurrenciesViaExecutor() public virtual impersonate(ALICE, true) {
		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), 0);
		}

		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), MAX_UINT256);
		}
	}

	function test_approveCurrencies() public virtual {
		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), 0);
		}

		bytes memory callData = abi.encodeCall(
			PERMIT2_EXECUTOR.approveCurrencies,
			(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI))
		);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), MAX_UINT256);
		}
	}

	function test_approveViaExecutor() public virtual impersonate(ALICE, true) {
		(uint160 amount, uint48 expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, 0);
		assertEq(expiration, 0);

		PERMIT2_EXECUTOR.approve(WSTETH, spender, MAX_UINT160, MAX_UINT48);

		(amount, expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, MAX_UINT160);
		assertEq(expiration, MAX_UINT48);
	}

	function test_approve() public virtual {
		(uint160 amount, uint48 expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, 0);
		assertEq(expiration, 0);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.approve, (WSTETH, spender, MAX_UINT160, MAX_UINT48));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

		(amount, expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, MAX_UINT160);
		assertEq(expiration, MAX_UINT48);
	}

	function test_getNonce() public virtual impersonate(ALICE, true) {
		Currency currency = WSTETH;

		(, , uint48 nonce) = PERMIT2.allowance(address(ALICE.account), currency, spender);
		assertEq(nonce, PERMIT2_EXECUTOR.getNonce(address(ALICE.account), currency, spender));
		assertEq(nonce, 0);

		(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currency, spender);

		bytes memory callData = abi.encodeWithSelector(0x2b67b570, address(ALICE.account), permit, signature);

		(bool success, ) = address(PERMIT2).call(callData);
		assertTrue(success);

		(, , nonce) = PERMIT2.allowance(address(ALICE.account), currency, spender);
		assertEq(nonce, PERMIT2_EXECUTOR.getNonce(address(ALICE.account), currency, spender));
		assertEq(nonce, 1);
	}

	function test_approveAndPermitSingle() public virtual {
		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currencies[i], spender);

			bytes memory params = abi.encode(permit, signature);

			Execution[] memory executions = new Execution[](2);

			executions[0] = Execution({
				target: currencies[i].toAddress(),
				value: 0,
				callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
			});

			executions[1] = Execution({
				target: address(PERMIT2_EXECUTOR),
				value: 0,
				callData: abi.encodeCall(PERMIT2_EXECUTOR.permitSingle, (params))
			});

			bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(executions);

			PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
			(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

			vm.prank(BUNDLER.eoa);
			ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingleViaExecutor() public virtual impersonate(ALICE, true) {
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currencies[i], spender);

			bytes memory params = abi.encode(permit, signature);

			PERMIT2_EXECUTOR.permitSingle(params);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingle() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currencies[i], spender);

			bytes memory params = abi.encode(permit, signature);

			bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitSingle, (params));

			bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(PERMIT2_EXECUTOR),
				0,
				callData
			);

			PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
			(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

			vm.prank(BUNDLER.eoa);
			ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingle_revertsWithInvalidSignature() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		revertToState();

		for (uint256 i; i < currencies.length; ++i) {
			(PermitSingle memory permit, , bytes32 hash) = preparePermitSingle(ALICE, currencies[i], spender);

			bytes memory signature = abi.encodePacked(K1_VALIDATOR, MURPHY.sign(hash));

			bytes memory params = abi.encode(permit, signature);

			bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitSingle, (params));

			bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
				address(PERMIT2_EXECUTOR),
				0,
				callData
			);

			PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
			bytes32 userOpHash;

			(userOps[0], userOpHash) = ALICE.prepareUserOp(executionCalldata);

			vm.expectEmit(true, true, true, true);
			emit IEntryPoint.UserOperationRevertReason(
				userOpHash,
				address(ALICE.account),
				userOps[0].nonce,
				abi.encodeWithSelector(InvalidContractSignature.selector)
			);

			vm.prank(BUNDLER.eoa);
			ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

			revertToState();
		}
	}

	function test_approveAndPermitBatch() public virtual {
		Execution[] memory executions = new Execution[](currencies.length + 1);

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			executions[i] = Execution({
				target: currencies[i].toAddress(),
				value: 0,
				callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
			});
		}

		(PermitBatch memory permit, bytes memory signature, ) = preparePermitBatch(ALICE, currencies, spender);

		bytes memory params = abi.encode(permit, signature);

		executions[currencies.length] = Execution({
			target: address(PERMIT2_EXECUTOR),
			value: 0,
			callData: abi.encodeCall(PERMIT2_EXECUTOR.permitBatch, (params))
		});

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(executions);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitBatchViaExecutor() public virtual impersonate(ALICE, true) {
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);
		}

		(PermitBatch memory permit, bytes memory signature, ) = preparePermitBatch(ALICE, currencies, spender);

		bytes memory params = abi.encode(permit, signature);

		PERMIT2_EXECUTOR.permitBatch(params);

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitBatch() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);
		}

		(PermitBatch memory permit, bytes memory signature, ) = preparePermitBatch(ALICE, currencies, spender);

		bytes memory params = abi.encode(permit, signature);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitBatch, (params));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitBatch_revertsWithInvalidSignature() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		(PermitBatch memory permit, , bytes32 hash) = preparePermitBatch(ALICE, currencies, spender);

		bytes memory invalidSignature = abi.encodePacked(K1_VALIDATOR, MURPHY.sign(hash));

		bytes memory params = abi.encode(permit, invalidSignature);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitBatch, (params));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = ALICE.prepareUserOp(executionCalldata);

		vm.expectEmit(true, true, true, true);
		emit IEntryPoint.UserOperationRevertReason(
			userOpHash,
			address(ALICE.account),
			userOps[0].nonce,
			abi.encodeWithSelector(InvalidContractSignature.selector)
		);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);
	}
}
