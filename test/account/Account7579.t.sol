// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {Currency} from "src/types/Currency.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {Signer} from "test/shared/structs/Signer.sol";

import {MockERC721} from "test/shared/mocks/MockERC721.sol";
import {MockERC1155} from "test/shared/mocks/MockERC1155.sol";
import {MockExecutor} from "test/shared/mocks/MockExecutor.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {MockValidator} from "test/shared/mocks/MockValidator.sol";
import {MockTarget} from "test/shared/mocks/MockTarget.sol";

import {SolArray} from "test/shared/utils/SolArray.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";

contract Account7579Test is BaseTest {
	using AccountIdLib for string;
	using ExecutionUtils for ExecType;
	using SolArray for *;

	MockTarget internal MOCK;

	function setUp() public virtual override {
		super.setUp();
		MOCK = new MockTarget();
		setUpAccounts();
	}

	function test_deployment() public virtual {
		validateAccountCreation(ALICE.account, ALICE.eoa);
		validateAccountCreation(COOPER.account, COOPER.eoa);
		validateAccountCreation(MURPHY.account, MURPHY.eoa);
	}

	function test_initializeAccount_revertsIfAlreadyInitialized() public virtual {
		vm.expectRevert(InvalidInitialization.selector);
		VORTEX.initializeAccount("");
	}

	function test_onETHReceived() public virtual {
		uint256 balance = address(ALICE.account).balance;
		uint256 value = 1 ether;

		(bool success, ) = address(ALICE.account).call{value: value}("");

		assertTrue(success);
		assertEq(address(ALICE.account).balance, balance + value);
	}

	function test_onERC721Received() public virtual {
		MockERC721 erc721 = new MockERC721("Fomo WETH", "FOMO");
		uint256 tokenId = 1;

		erc721.mint(ALICE.eoa, tokenId);

		assertEq(erc721.balanceOf(ALICE.eoa), 1);
		assertEq(erc721.ownerOf(tokenId), ALICE.eoa);

		vm.expectEmit(true, true, true, true);
		emit MockERC721.Transfer(ALICE.eoa, address(ALICE.account), tokenId);

		vm.prank(ALICE.eoa);
		erc721.safeTransferFrom(ALICE.eoa, address(ALICE.account), tokenId);

		assertEq(erc721.balanceOf(address(ALICE.account)), 1);
		assertEq(erc721.ownerOf(tokenId), address(ALICE.account));
	}

	function test_onERC1155Received() public virtual {
		MockERC1155 erc1155 = new MockERC1155();
		uint256 tokenId = 1;

		erc1155.mint(ALICE.eoa, tokenId, 1, "");
		assertEq(erc1155.balanceOf(ALICE.eoa, tokenId), 1);

		vm.expectEmit(true, true, true, true);
		emit MockERC1155.TransferSingle(ALICE.eoa, ALICE.eoa, address(ALICE.account), tokenId, 1);

		vm.prank(ALICE.eoa);
		erc1155.safeTransferFrom(ALICE.eoa, address(ALICE.account), tokenId, 1, "");

		assertEq(erc1155.balanceOf(address(ALICE.account), tokenId), 1);
	}

	function test_onERC1155BatchReceived() public virtual {
		MockERC1155 erc1155 = new MockERC1155();

		erc1155.mint(ALICE.eoa, 1, 1, "");
		erc1155.mint(ALICE.eoa, 2, 1, "");

		assertEq(erc1155.balanceOf(ALICE.eoa, 1), 1);
		assertEq(erc1155.balanceOf(ALICE.eoa, 2), 1);

		uint256[] memory tokenIds = SolArray.uint256s(1, 2);
		uint256[] memory amounts = SolArray.uint256s(1, 1);

		vm.expectEmit(true, true, true, true);
		emit MockERC1155.TransferBatch(ALICE.eoa, ALICE.eoa, address(ALICE.account), tokenIds, amounts);

		vm.prank(ALICE.eoa);
		erc1155.safeBatchTransferFrom(ALICE.eoa, address(ALICE.account), tokenIds, amounts, "");

		assertEq(erc1155.balanceOf(address(ALICE.account), 1), 1);
		assertEq(erc1155.balanceOf(address(ALICE.account), 2), 1);
	}

	function test_fallback(CallType callType, bytes32 value) public virtual asEntryPoint {
		vm.assume(callType == CALLTYPE_SINGLE || callType == CALLTYPE_STATIC || callType == CALLTYPE_DELEGATE);

		MockFallback account = MockFallback(payable(address(COOPER.account)));

		if (callType == CALLTYPE_SINGLE) {
			vm.expectEmit(true, true, true, true);
			emit MockFallback.FallbackCall(address(ENTRYPOINT), value);

			account.fallbackSingle(value);

			assertEq(account.fallbackStatic(address(COOPER.account)), value);
			assertEq(MOCK_FALLBACK.fallbackStatic(address(COOPER.account)), value);
		} else if (callType == CALLTYPE_DELEGATE) {
			vm.expectEmit(true, true, true, true);
			emit MockFallback.FallbackDelegate(address(ENTRYPOINT), value);

			account.fallbackDelegate(value);
		} else if (callType == CALLTYPE_STATIC) {
			assertEq(account.fallbackSuccess(), keccak256("SUCCESS"));
		}
	}

	function test_fallback_revertsWhenUnknownSelectorsInvoked() public virtual asEntryPoint {
		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackSingle.selector));
		MockFallback(payable(address(MURPHY.account))).fallbackSingle(bytes32(vm.randomBytes(32)));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackDelegate.selector));
		MockFallback(payable(address(MURPHY.account))).fallbackDelegate(bytes32(vm.randomBytes(32)));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackStatic.selector));
		MockFallback(payable(address(MURPHY.account))).fallbackStatic(address(MURPHY.account));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackSuccess.selector));
		MockFallback(payable(address(MURPHY.account))).fallbackSuccess();
	}

	function test_executeUserOp() public virtual {
		COOPER.install(
			TYPE_FALLBACK,
			address(NATIVE_WRAPPER),
			encodeInstallModuleParams(
				TYPE_FALLBACK.moduleTypes(),
				abi.encode(
					encodeFallbackSelectors(
						NativeWrapper.wrapETH.selector.bytes4s(NativeWrapper.unwrapWETH.selector),
						CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE)
					),
					""
				),
				""
			)
		);

		uint256 value = 5 ether;
		bytes memory callData = abi.encodeCall(NativeWrapper.wrapETH, (value));

		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(userOpCalldata);

		deal(address(COOPER.account), value);
		assertEq(address(COOPER.account).balance, value);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		ENTRYPOINT.handleOps(userOps, COOPER.eoa);

		assertEq(address(COOPER.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), value);
	}

	function test_executeUserOpWithExecute() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;
		bytes memory callData = abi.encodeWithSignature("deposit()");

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(target, value, callData);

		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, executionCalldata);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(userOpCalldata);

		deal(address(COOPER.account), address(COOPER.account).balance + value);
		assertGe(address(COOPER.account).balance, value);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		ENTRYPOINT.handleOps(userOps, COOPER.eoa);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), value);
	}

	function test_executeUserOpWithExecuteFromExecutor() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;
		bytes memory callData = abi.encodeWithSignature("deposit()");

		bytes memory executorCalldata = abi.encodeCall(
			MockExecutor.executeViaAccount,
			(COOPER.account, target, value, callData)
		);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(MOCK_EXECUTOR),
			0,
			executorCalldata
		);

		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, executionCalldata);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(userOpCalldata);

		deal(address(COOPER.account), address(COOPER.account).balance + value);
		assertGe(address(COOPER.account).balance, value);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		ENTRYPOINT.handleOps(userOps, COOPER.eoa);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), value);
	}

	function test_execute(CallType callType, ExecType execType, bool shouldRevert) public virtual {
		vm.assume(callType == CALLTYPE_SINGLE || callType == CALLTYPE_BATCH || callType == CALLTYPE_DELEGATE);
		vm.assume(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(callType, execType);
		assertTrue(COOPER.account.supportsExecutionMode(mode));

		address expectedSender;
		bytes memory executionCalldata;
		bytes memory callData = abi.encodeCall(MockTarget.emitEvent, (shouldRevert));

		if (callType == CALLTYPE_BATCH) {
			Execution[] memory executions = new Execution[](1);
			executions[0] = Execution({target: address(MOCK), value: 0, callData: callData});

			expectedSender = address(COOPER.account);
			executionCalldata = execType.encodeExecutionCalldata(executions);
		} else if (callType == CALLTYPE_SINGLE) {
			expectedSender = address(COOPER.account);
			executionCalldata = execType.encodeExecutionCalldata(address(MOCK), 0, callData);
		} else if (callType == CALLTYPE_DELEGATE) {
			expectedSender = address(ENTRYPOINT);
			executionCalldata = execType.encodeExecutionCalldata(address(MOCK), callData);
		}

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = COOPER.prepareUserOp(executionCalldata);

		if (shouldRevert) {
			bytes memory revertReason = abi.encodeWithSignature("Error(string)", "MockTarget: Revert operation");

			if (execType == EXECTYPE_TRY) {
				vm.expectEmit(true, true, true, true);
				emit TryExecuteUnsuccessful(0, revertReason);
			} else {
				vm.expectEmit(true, true, true, true);
				emit IEntryPoint.UserOperationRevertReason(
					userOpHash,
					address(COOPER.account),
					userOps[0].nonce,
					revertReason
				);
			}
		} else {
			vm.expectEmit(true, true, true, true);
			emit MockTarget.Log(expectedSender, callType == CALLTYPE_DELEGATE);

			vm.expectEmit(true, true, true, false);
			emit IEntryPoint.UserOperationEvent(
				userOpHash,
				address(COOPER.account),
				address(0),
				userOps[0].nonce,
				true,
				0,
				0
			);
		}

		ENTRYPOINT.handleOps(userOps, COOPER.eoa);
	}

	function test_execute_revertsIfNotCalledByEntryPointOrSelf() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;
		bytes memory callData = abi.encodeWithSignature("deposit()");

		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		vm.expectRevert(UnauthorizedCallContext.selector);
		ALICE.account.execute(mode, executionCalldata);

		vm.expectRevert(UnauthorizedCallContext.selector);
		vm.prank(ALICE.eoa);
		ALICE.account.execute(mode, executionCalldata);
	}

	function test_executeTransferNative() public virtual {
		address recipient = makeAddr("recipient");
		uint256 value = 5 ether;

		deal(address(ALICE.account), address(ALICE.account).balance + value);
		assertGe(address(ALICE.account).balance, value);
		assertEq(recipient.balance, 0);

		ALICE.execute(EXECTYPE_DEFAULT, recipient, value, "");
		assertEq(recipient.balance, value);
	}

	function test_executeTransferCurrency() public virtual {
		address target = USDC.toAddress();
		uint256 amount = 50000 * 10 ** 6;
		bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", ALICE.eoa, amount);

		deal(USDC, address(ALICE.account), amount);
		assertEq(USDC.balanceOf(address(ALICE.account)), amount);
		assertEq(USDC.balanceOf(ALICE.eoa), 0);

		ALICE.execute(EXECTYPE_DEFAULT, target, 0, callData);

		assertEq(USDC.balanceOf(address(ALICE.account)), 0);
		assertEq(USDC.balanceOf(ALICE.eoa), amount);
	}

	function test_executeSingle() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;
		bytes memory callData = abi.encodeWithSignature("deposit()");

		deal(address(ALICE.account), address(ALICE.account).balance + value);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), 0);

		ALICE.execute(EXECTYPE_DEFAULT, target, value, callData);
		assertEq(WNATIVE.balanceOf(address(ALICE.account)), value);
	}

	function test_executeBatch() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;

		Execution[] memory executions = new Execution[](2);

		executions[0] = Execution({target: target, value: value, callData: abi.encodeWithSignature("deposit()")});

		executions[1] = Execution({
			target: target,
			value: 0,
			callData: abi.encodeWithSignature("transfer(address,uint256)", ALICE.eoa, value)
		});

		deal(address(ALICE.account), address(ALICE.account).balance + value);
		assertEq(WNATIVE.balanceOf(ALICE.eoa), 0);

		ALICE.execute(EXECTYPE_DEFAULT, executions);
		assertEq(WNATIVE.balanceOf(ALICE.eoa), value);
	}

	function test_executeFromExecutor(CallType callType, ExecType execType) public virtual {
		vm.assume(callType == CALLTYPE_SINGLE || callType == CALLTYPE_BATCH || callType == CALLTYPE_DELEGATE);
		vm.assume(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(callType, execType);
		assertTrue(COOPER.account.supportsExecutionMode(mode));

		bytes memory callData = abi.encodeCall(MockTarget.increment, ());
		bytes memory executorCalldata;
		uint256 expectedValue;

		if (callType == CALLTYPE_BATCH) {
			Execution[] memory executions = new Execution[](2);
			executions[0] = Execution({target: address(MOCK), value: 0, callData: callData});
			executions[1] = Execution({target: address(MOCK), value: 0, callData: callData});

			executorCalldata = execType == EXECTYPE_DEFAULT
				? abi.encodeCall(MockExecutor.executeBatchViaAccount, (COOPER.account, executions))
				: abi.encodeCall(MockExecutor.tryExecuteBatchViaAccount, (COOPER.account, executions));

			expectedValue = 2;
		} else if (callType == CALLTYPE_SINGLE) {
			executorCalldata = execType == EXECTYPE_DEFAULT
				? abi.encodeCall(MockExecutor.executeViaAccount, (COOPER.account, address(MOCK), 0, callData))
				: abi.encodeCall(MockExecutor.tryExecuteViaAccount, (COOPER.account, address(MOCK), 0, callData));

			expectedValue = 1;
		} else if (callType == CALLTYPE_DELEGATE) {
			executorCalldata = execType == EXECTYPE_DEFAULT
				? abi.encodeCall(MockExecutor.executeDelegateViaAccount, (COOPER.account, address(MOCK), callData))
				: abi.encodeCall(MockExecutor.tryExecuteDelegateViaAccount, (COOPER.account, address(MOCK), callData));

			expectedValue = 0;
		}

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(MOCK_EXECUTOR),
			0,
			executorCalldata
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		if (callType == CALLTYPE_BATCH) {
			vm.expectEmit(true, true, true, true);
			emit MockTarget.Incremented(address(COOPER.account), 1, false);

			vm.expectEmit(true, true, true, true);
			emit MockTarget.Incremented(address(COOPER.account), 2, false);
		} else if (callType == CALLTYPE_SINGLE) {
			vm.expectEmit(true, true, true, true);
			emit MockTarget.Incremented(address(COOPER.account), 1, false);
		} else if (callType == CALLTYPE_DELEGATE) {
			vm.expectEmit(true, true, true, true);
			emit MockTarget.Incremented(address(MOCK_EXECUTOR), 1, true);
		}

		ENTRYPOINT.handleOps(userOps, COOPER.eoa);
		assertEq(MOCK.getCounter(), expectedValue);
	}

	function test_executeFromExecutor_revertsIfCalledByInvalidExecutor() public virtual {
		bytes memory callData = abi.encodeCall(
			MockExecutor.executeViaAccount,
			(MURPHY.account, address(MOCK), 0, abi.encodeCall(MockTarget.increment, ()))
		);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MOCK_EXECUTOR), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = MURPHY.prepareUserOp(executionCalldata);

		bytes memory revertReason = abi.encodeWithSelector(ModuleNotInstalled.selector, MOCK_EXECUTOR);

		vm.expectEmit(true, true, true, true, address(ENTRYPOINT));
		emit IEntryPoint.UserOperationRevertReason(userOpHash, address(MURPHY.account), userOps[0].nonce, revertReason);

		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);
	}

	function test_executeFromExecutorTransferNative() public virtual {
		address recipient = makeAddr("recipient");
		uint256 value = 5 ether;

		deal(address(COOPER.account), address(COOPER.account).balance + value);
		assertGe(address(COOPER.account).balance, value);
		assertEq(recipient.balance, 0);

		MOCK_EXECUTOR.executeViaAccount(COOPER.account, recipient, value, "");
		assertEq(recipient.balance, value);
	}

	function test_executeFromExecutorTransfer() public virtual {
		address target = USDC.toAddress();
		uint256 amount = 50000 * 10 ** 6;
		bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", COOPER.eoa, amount);

		deal(USDC, address(COOPER.account), amount);
		assertEq(USDC.balanceOf(address(COOPER.account)), amount);
		assertEq(USDC.balanceOf(COOPER.eoa), 0);

		MOCK_EXECUTOR.executeViaAccount(COOPER.account, target, 0, callData);
		assertEq(USDC.balanceOf(COOPER.eoa), amount);
	}

	function test_executeSingleFromExecutor() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;
		bytes memory callData = abi.encodeWithSignature("deposit()");

		deal(address(COOPER.account), address(COOPER.account).balance + value);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		MOCK_EXECUTOR.executeViaAccount(COOPER.account, target, value, callData);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), value);
	}

	function test_executeBatchFromExecutor() public virtual {
		address target = WNATIVE.toAddress();
		uint256 value = 5 ether;

		Execution[] memory executions = new Execution[](2);

		executions[0] = Execution({target: target, value: value, callData: abi.encodeWithSignature("deposit()")});

		executions[1] = Execution({
			target: target,
			value: 0,
			callData: abi.encodeWithSignature("transfer(address,uint256)", COOPER.eoa, value)
		});

		deal(address(COOPER.account), address(COOPER.account).balance + value);
		assertEq(WNATIVE.balanceOf(COOPER.eoa), 0);

		bytes[] memory returnData = MOCK_EXECUTOR.executeBatchViaAccount(COOPER.account, executions);
		assertEq(returnData.length, 2);
		assertEq(WNATIVE.balanceOf(COOPER.eoa), value);
	}

	function test_executeBatchFromExecutorWithEmptyExecutions() public virtual {
		Execution[] memory executions = new Execution[](0);

		bytes[] memory returnData = MOCK_EXECUTOR.executeBatchViaAccount(COOPER.account, executions);
		assertEq(returnData.length, 0);
	}

	function test_isValidSignatureWithPersonalSign() public virtual {
		bytes32 contents = keccak256("wonderland");
		bytes32 structHash = keccak256(abi.encode(keccak256("PersonalSign(bytes prefixed)"), contents));
		bytes32 messageHash = ALICE.account.hashTypedData(structHash);

		bytes memory signature = abi.encodePacked(K1_VALIDATOR, ALICE.sign(messageHash));

		assertEq(ALICE.account.isValidSignature(contents, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignature() public virtual {
		bytes32 contents = keccak256("gravity equation");
		bytes memory contentsType = "Contents(bytes32 hash)";

		(bytes32 contentsHash, bytes32 messageHash) = toERC1271Hash(MURPHY.account, contents);

		bytes memory innerSignature = abi.encodePacked(
			MURPHY.sign(messageHash),
			MURPHY.account.DOMAIN_SEPARATOR(),
			contents,
			contentsType,
			uint16(contentsType.length)
		);

		bytes memory signature = abi.encodePacked(K1_VALIDATOR, innerSignature);
		bytes memory wrappedSignature = abi.encodePacked(K1_VALIDATOR, erc6492Wrap(innerSignature));

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
		assertEq(MURPHY.account.isValidSignature(contentsHash, wrappedSignature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithInvalidSigner() public virtual {
		bytes32 contents = keccak256("gargantua");
		bytes memory contentsType = "Contents(bytes32 hash)";

		(bytes32 contentsHash, bytes32 messageHash) = toERC1271Hash(MURPHY.account, contents);

		bytes memory innerSignature = abi.encodePacked(
			COOPER.sign(messageHash),
			MURPHY.account.DOMAIN_SEPARATOR(),
			contents,
			contentsType,
			uint16(contentsType.length)
		);

		bytes memory signature = abi.encodePacked(K1_VALIDATOR, innerSignature);

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_FAILED);
	}

	function test_isValidSignatureWithERC6492Unwrapping() public virtual {
		bytes32 contents = keccak256(abi.encodePacked("ERC6492Unwrapping"));
		bytes memory contentsType = "Contents(bytes32 hash)";

		(bytes32 contentsHash, bytes32 messageHash) = toERC1271Hash(MURPHY.account, contents);

		bytes memory innerSignature = abi.encodePacked(
			MURPHY.sign(messageHash),
			MURPHY.account.DOMAIN_SEPARATOR(),
			contents,
			contentsType,
			uint16(contentsType.length)
		);

		bytes memory signature = abi.encodePacked(K1_VALIDATOR, erc6492Wrap(innerSignature));

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithoutERC6492Unwrapping() public virtual {
		bytes32 contents = keccak256(abi.encodePacked("ERC6492Unwrapping"));
		bytes memory contentsType = "Contents(bytes32 hash)";

		(bytes32 contentsHash, bytes32 messageHash) = toERC1271Hash(MURPHY.account, contents);

		bytes memory innerSignature = abi.encodePacked(
			MURPHY.sign(messageHash),
			MURPHY.account.DOMAIN_SEPARATOR(),
			contents,
			contentsType,
			uint16(contentsType.length)
		);

		bytes memory signature = abi.encodePacked(K1_VALIDATOR, innerSignature);

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithERC7739() public virtual asEntryPoint {
		assertEq(ALICE.account.isValidSignature(bytes32((MAX_UINT256 / 0xffff) * 0x7739), ""), bytes4(0x77390001));
	}

	function toERC1271Hash(
		Vortex account,
		bytes32 contents
	) internal view virtual returns (bytes32 contentsHash, bytes32 messageHash) {
		(string memory name, string memory version) = account.accountId().parse();

		bytes memory domainFields = abi.encode(
			keccak256(bytes(name)),
			keccak256(bytes(version)),
			block.chainid,
			account,
			bytes32(0)
		);

		bytes32 structHash = keccak256(
			abi.encodePacked(
				abi.encode(
					keccak256(
						"TypedDataSign(Contents contents,string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)Contents(bytes32 hash)"
					),
					contents
				),
				domainFields
			)
		);

		contentsHash = account.hashTypedData(contents);
		messageHash = account.hashTypedData(structHash);
	}

	function erc6492Wrap(bytes memory signature) internal virtual returns (bytes memory) {
		return
			abi.encodePacked(
				abi.encode(randomAddress(), bytes(randomString("12345")), signature),
				bytes32((MAX_UINT256 / 0xffff) * 0x6492)
			);
	}

	function validateAccountCreation(Vortex account, address owner) internal view virtual {
		assertContract(address(account));
		assertEq(bytes32ToAddress(vm.load(address(account), ERC1967_IMPLEMENTATION_SLOT)), address(VORTEX));
		assertEq(account.implementation(), address(VORTEX));
		assertEq(account.accountId(), "fomoweth.vortex.1.0.0");

		assertEq(account.rootValidator(), address(K1_VALIDATOR));
		assertEq(K1_VALIDATOR.getAccountOwner(address(account)), owner);
		assertTrue(K1_VALIDATOR.isAuthorized(address(account), BUNDLER.eoa));

		if (owner != MURPHY.eoa) assertEq(account.registry(), address(REGISTRY));

		assertTrue(
			account.supportsModule(TYPE_VALIDATOR) &&
				account.supportsModule(TYPE_EXECUTOR) &&
				account.supportsModule(TYPE_FALLBACK) &&
				account.supportsModule(TYPE_HOOK)
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeSingle()) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeTrySingle())
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeBatch()) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeTryBatch())
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeDelegate()) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeTryDelegate())
		);
	}
}
