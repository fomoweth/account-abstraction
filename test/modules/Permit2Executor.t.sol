// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Currency} from "src/types/Currency.sol";
import {ExecType} from "src/types/ExecutionMode.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {PermitDetails, PermitSingle, PermitBatch} from "test/shared/structs/Protocols.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";

contract Permit2ExecutorTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	error InvalidContractSignature();

	address internal immutable spender = makeAddr("SPENDER");

	Currency[] internal currencies;

	function setUp() public virtual override {
		super.setUp();

		currencies = WNATIVE.currencies(WSTETH, USDC, DAI);

		deployVortex(ALICE, 0, INITIAL_VALUE, address(VORTEX_FACTORY), true);

		ALICE.install(
			TYPE_EXECUTOR,
			address(PERMIT2_EXECUTOR),
			encodeInstallModuleData(TYPE_EXECUTOR.moduleTypes(), "", "")
		);
	}

	function test_approveCurrenciesViaExecutor() public virtual impersonate(address(ALICE.account)) {
		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), 0);
		}

		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), MAX_UINT256);
		}
	}

	function test_approveCurrenciesViaEntryPoint() public virtual {
		for (uint256 i; i < currencies.length; ++i) {
			assertEq(currencies[i].allowance(address(ALICE.account), address(PERMIT2)), 0);
		}

		bytes memory callData = abi.encodeCall(
			PERMIT2_EXECUTOR.approveCurrencies,
			(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI))
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

	function test_approveViaExecutor() public virtual impersonate(address(ALICE.account)) {
		(uint160 amount, uint48 expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, 0);
		assertEq(expiration, 0);

		PERMIT2_EXECUTOR.approve(address(ALICE.account), WSTETH, spender, MAX_UINT160, MAX_UINT48);

		(amount, expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, MAX_UINT160);
		assertEq(expiration, MAX_UINT48);
	}

	function test_approveViaEntryPoint() public virtual {
		(uint160 amount, uint48 expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, 0);
		assertEq(expiration, 0);

		bytes memory callData = abi.encodeCall(
			PERMIT2_EXECUTOR.approve,
			(address(ALICE.account), WSTETH, spender, MAX_UINT160, MAX_UINT48)
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

		(amount, expiration, ) = PERMIT2.allowance(address(ALICE.account), WSTETH, spender);
		assertEq(amount, MAX_UINT160);
		assertEq(expiration, MAX_UINT48);
	}

	function test_getNonce() public virtual impersonate(address(ALICE.account)) {
		Currency currency = WSTETH;

		(, , uint48 nonce) = PERMIT2.allowance(address(ALICE.account), currency, spender);
		assertEq(nonce, PERMIT2_EXECUTOR.getNonce(address(ALICE.account), currency, spender));
		assertEq(nonce, 0);

		(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currency);

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

			executePermitSingle(currencies[i], ALICE, BUNDLER.eoa);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingleViaExecutor() public virtual impersonate(address(ALICE.account)) {
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(ALICE, currencies[i]);

			bytes memory params = abi.encode(permit, signature);

			PERMIT2_EXECUTOR.permitSingle(address(ALICE.account), params);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingleViaEntryPoint() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		for (uint256 i; i < currencies.length; ++i) {
			(uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(
				address(ALICE.account),
				currencies[i],
				spender
			);

			assertEq(amount, 0);
			assertEq(expiration, 0);
			assertEq(nonce, 0);

			executePermitSingle(currencies[i], ALICE, BUNDLER.eoa);

			(amount, expiration, nonce) = PERMIT2.allowance(address(ALICE.account), currencies[i], spender);

			assertEq(amount, MAX_UINT160);
			assertEq(expiration, MAX_UINT48);
			assertEq(nonce, 1);
		}
	}

	function test_permitSingle_revertsWithInvalidSignature() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		revertToState();

		for (uint256 i; i < currencies.length; ++i) {
			(PermitSingle memory permit, , bytes32 hash) = preparePermitSingle(ALICE, currencies[i]);

			bytes memory signature = abi.encodePacked(K1_VALIDATOR, MURPHY.sign(hash));

			bytes memory params = abi.encode(permit, signature);

			// vm.expectRevert(InvalidContractSignature.selector);
			// PERMIT2_EXECUTOR.permitSingle(address(ALICE.account), params);

			bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitSingle, (address(ALICE.account), params));

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

		executePermitBatch(ALICE, BUNDLER.eoa);

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

	function test_permitBatchViaExecutor() public virtual impersonate(address(ALICE.account)) {
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

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

		(PermitBatch memory permit, bytes memory signature, ) = preparePermitBatch(ALICE);

		bytes memory params = abi.encode(permit, signature);

		PERMIT2_EXECUTOR.permitBatch(address(ALICE.account), params);

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

	function test_permitBatchViaEntryPoint() public virtual {
		vm.prank(address(ALICE.account));
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

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

		executePermitBatch(ALICE, BUNDLER.eoa);

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
		PERMIT2_EXECUTOR.approveCurrencies(address(ALICE.account), abi.encodePacked(WNATIVE, WSTETH, USDC, DAI));

		(PermitBatch memory permit, , bytes32 hash) = preparePermitBatch(ALICE);

		bytes memory invalidSignature = abi.encodePacked(K1_VALIDATOR, MURPHY.sign(hash));

		bytes memory params = abi.encode(permit, invalidSignature);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitBatch, (address(ALICE.account), params));

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
			ENTRYPOINT.getUserOpHash(userOps[0]),
			address(ALICE.account),
			userOps[0].nonce,
			abi.encodeWithSelector(InvalidContractSignature.selector)
		);

		vm.prank(BUNDLER.eoa);
		ENTRYPOINT.handleOps(userOps, BUNDLER.eoa);
	}

	function executePermitSingle(
		Currency currency,
		Signer memory signer,
		address payable beneficiary
	) internal virtual {
		(PermitSingle memory permit, bytes memory signature, ) = preparePermitSingle(signer, currency);

		bytes memory params = abi.encode(permit, signature);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitSingle, (address(signer.account), params));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(beneficiary);
		ENTRYPOINT.handleOps(userOps, beneficiary);
	}

	function executePermitBatch(Signer memory signer, address payable beneficiary) internal virtual {
		(PermitBatch memory permit, bytes memory signature, ) = preparePermitBatch(signer);

		bytes memory params = abi.encode(permit, signature);

		bytes memory callData = abi.encodeCall(PERMIT2_EXECUTOR.permitBatch, (address(signer.account), params));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(PERMIT2_EXECUTOR),
			0,
			callData
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = ALICE.prepareUserOp(executionCalldata);

		vm.prank(beneficiary);
		ENTRYPOINT.handleOps(userOps, beneficiary);
	}

	function preparePermitSingle(
		Signer memory signer,
		Currency currency
	) internal view virtual returns (PermitSingle memory permit, bytes memory signature, bytes32 hash) {
		(, , uint48 nonce) = PERMIT2.allowance(address(signer.account), currency, spender);

		permit = PermitSingle({
			details: PermitDetails({currency: currency, amount: MAX_UINT160, expiration: MAX_UINT48, nonce: nonce}),
			spender: spender,
			sigDeadline: MAX_UINT256
		});

		bytes32 structHash = keccak256(
			abi.encode(
				PERMIT_SINGLE_TYPEHASH,
				keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permit.details)),
				spender,
				MAX_UINT256
			)
		);

		hash = keccak256(abi.encodePacked("\x19\x01", PERMIT2.DOMAIN_SEPARATOR(), structHash));

		signature = abi.encodePacked(K1_VALIDATOR, signer.sign(hash));
	}

	function preparePermitBatch(
		Signer memory signer
	) internal view virtual returns (PermitBatch memory permit, bytes memory signature, bytes32 hash) {
		uint256 length = currencies.length;
		PermitDetails[] memory details = new PermitDetails[](length);
		bytes32[] memory hashes = new bytes32[](length);

		for (uint256 i; i < length; ++i) {
			(, , uint48 nonce) = PERMIT2.allowance(address(signer.account), currencies[i], spender);

			hashes[i] = keccak256(
				abi.encode(
					PERMIT_DETAILS_TYPEHASH,
					details[i] = PermitDetails({
						currency: currencies[i],
						amount: MAX_UINT160,
						expiration: MAX_UINT48,
						nonce: nonce
					})
				)
			);
		}

		permit = PermitBatch({details: details, spender: spender, sigDeadline: MAX_UINT256});

		bytes32 structHash = keccak256(
			abi.encode(PERMIT_BATCH_TYPEHASH, keccak256(abi.encodePacked(hashes)), spender, MAX_UINT256)
		);

		hash = keccak256(abi.encodePacked("\x19\x01", PERMIT2.DOMAIN_SEPARATOR(), structHash));

		signature = abi.encodePacked(K1_VALIDATOR, signer.sign(hash));
	}
}
