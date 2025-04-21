// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {Currency} from "src/types/Currency.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {MockERC721} from "test/shared/mocks/MockERC721.sol";
import {MockERC1155} from "test/shared/mocks/MockERC1155.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockTarget} from "test/shared/mocks/MockTarget.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract Account7579Test is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	address internal immutable recipient = makeAddr("recipient");
	uint256 internal constant USDC_AMOUNT = 50000 * 10 ** 6;
	MockTarget internal MOCK;

	function setUp() public virtual override {
		super.setUp();

		setUpAccounts();

		bytes4[] memory selectors = NativeWrapperFallback.wrap.selector.bytes4s(NativeWrapperFallback.unwrap.selector);

		CallType[] memory callTypes = CALLTYPE_DELEGATE.callTypes(CALLTYPE_DELEGATE);

		COOPER.install(
			TYPE_FALLBACK,
			address(aux.nativeWrapper),
			encodeModuleParams(abi.encode(encodeFallbackSelectors(selectors, callTypes), ""), "")
		);

		MOCK = new MockTarget();
	}

	function test_deployments() public virtual {
		validateAccountCreation(ALICE.account, ALICE.eoa);
		validateAccountCreation(COOPER.account, COOPER.eoa);
		validateAccountCreation(MURPHY.account, MURPHY.eoa);
	}

	function test_initialize_revertsIfAlreadyInitialized() public virtual {
		vm.expectRevert(InvalidInitialization.selector);
		aux.vortex.initializeAccount("");
	}

	function test_onETHReceived() public virtual {
		uint256 balance = address(COOPER.account).balance;
		uint256 value = 1 ether;

		(bool success, ) = address(COOPER.account).call{value: value}("");

		assertTrue(success);
		assertEq(address(COOPER.account).balance, balance + value);
	}

	function test_onERC721Received() public virtual {
		MockERC721 erc721 = new MockERC721("Fomo WETH", "FOMO");
		uint256 tokenId = 1;

		erc721.mint(COOPER.eoa, tokenId);

		assertEq(erc721.balanceOf(COOPER.eoa), 1);
		assertEq(erc721.ownerOf(tokenId), COOPER.eoa);

		vm.expectEmit(true, true, true, true);
		emit MockERC721.Transfer(COOPER.eoa, address(COOPER.account), tokenId);

		vm.prank(COOPER.eoa);
		erc721.safeTransferFrom(COOPER.eoa, address(COOPER.account), tokenId);

		assertEq(erc721.balanceOf(address(COOPER.account)), 1);
		assertEq(erc721.ownerOf(tokenId), address(COOPER.account));
	}

	function test_onERC1155Received() public virtual {
		MockERC1155 erc1155 = new MockERC1155();
		uint256 tokenId = 1;

		erc1155.mint(COOPER.eoa, tokenId, 1, "");
		assertEq(erc1155.balanceOf(COOPER.eoa, tokenId), 1);

		vm.expectEmit(true, true, true, true);
		emit MockERC1155.TransferSingle(COOPER.eoa, COOPER.eoa, address(COOPER.account), tokenId, 1);

		vm.prank(COOPER.eoa);
		erc1155.safeTransferFrom(COOPER.eoa, address(COOPER.account), tokenId, 1, "");

		assertEq(erc1155.balanceOf(address(COOPER.account), tokenId), 1);
	}

	function test_onERC1155BatchReceived() public virtual {
		MockERC1155 erc1155 = new MockERC1155();

		erc1155.mint(COOPER.eoa, 1, 1, "");
		erc1155.mint(COOPER.eoa, 2, 1, "");

		assertEq(erc1155.balanceOf(COOPER.eoa, 1), 1);
		assertEq(erc1155.balanceOf(COOPER.eoa, 2), 1);

		uint256[] memory tokenIds = SolArray.uint256s(1, 2);
		uint256[] memory amounts = SolArray.uint256s(1, 1);

		vm.expectEmit(true, true, true, true);
		emit MockERC1155.TransferBatch(COOPER.eoa, COOPER.eoa, address(COOPER.account), tokenIds, amounts);

		vm.prank(COOPER.eoa);
		erc1155.safeBatchTransferFrom(COOPER.eoa, address(COOPER.account), tokenIds, amounts, "");

		assertEq(erc1155.balanceOf(address(COOPER.account), 1), 1);
		assertEq(erc1155.balanceOf(address(COOPER.account), 2), 1);
	}

	function test_fallback(CallType callType, bytes32 value) public virtual asEntryPoint {
		vm.assume(callType == CALLTYPE_SINGLE || callType == CALLTYPE_STATIC || callType == CALLTYPE_DELEGATE);

		MockFallback account = MockFallback(address(COOPER.account));

		if (callType == CALLTYPE_SINGLE) {
			vm.expectEmit(true, true, true, true);
			emit MockFallback.FallbackCall(address(ENTRYPOINT), value);

			account.fallbackSingle(value);

			assertEq(account.fallbackStatic(address(COOPER.account)), value);
			assertEq(aux.mockFallback.fallbackStatic(address(COOPER.account)), value);
		} else if (callType == CALLTYPE_DELEGATE) {
			vm.expectEmit(true, true, true, true);
			emit MockFallback.FallbackDelegate(address(ENTRYPOINT), value);

			account.fallbackDelegate(value);
		} else if (callType == CALLTYPE_STATIC) {
			assertEq(account.fallbackSuccess(), keccak256("SUCCESS"));
		}
	}

	function test_fallback_revertsWhenUnknownSelectorsInvoked() public virtual asEntryPoint {
		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, NativeWrapperFallback.wrap.selector));
		NativeWrapperFallback(address(MURPHY.account)).wrap(1 ether);

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, NativeWrapperFallback.unwrap.selector));
		NativeWrapperFallback(address(MURPHY.account)).unwrap(1 ether);

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackSingle.selector));
		MockFallback(address(MURPHY.account)).fallbackSingle(bytes32(vm.randomBytes(32)));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackDelegate.selector));
		MockFallback(address(MURPHY.account)).fallbackDelegate(bytes32(vm.randomBytes(32)));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackStatic.selector));
		MockFallback(address(MURPHY.account)).fallbackStatic(address(MURPHY.account));

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, MockFallback.fallbackSuccess.selector));
		MockFallback(address(MURPHY.account)).fallbackSuccess();
	}

	function test_executeUserOp() public virtual {
		deal(address(COOPER.account), DEFAULT_VALUE);
		assertEq(address(COOPER.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		bytes memory callData = abi.encodePacked(
			Vortex.executeUserOp.selector,
			abi.encodeCall(NativeWrapperFallback.wrap, (DEFAULT_VALUE))
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(callData);

		BUNDLER.handleOps(userOps);

		assertEq(address(COOPER.account).balance, 0);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), DEFAULT_VALUE);
	}

	function test_executeUserOpWithExecute() internal virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertGe(address(COOPER.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			WNATIVE.toAddress(),
			DEFAULT_VALUE,
			abi.encodeWithSignature("deposit()")
		);

		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, executionCalldata);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), DEFAULT_VALUE);
	}

	function test_executeUserOpWithExecuteFromExecutor() internal virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertGe(address(COOPER.account).balance, DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(
				aux.mockExecutor.executeViaAccount,
				(COOPER.account, WNATIVE.toAddress(), DEFAULT_VALUE, abi.encodeWithSignature("deposit()"))
			)
		);

		bytes memory userOpCalldata = abi.encodePacked(Vortex.executeUserOp.selector, executionCalldata);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(userOpCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), DEFAULT_VALUE);
	}

	function test_execute(CallType callType, ExecType execType, bool shouldRevert) public virtual {
		vm.assume(callType == CALLTYPE_SINGLE || callType == CALLTYPE_BATCH || callType == CALLTYPE_DELEGATE);
		vm.assume(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(callType, execType);
		assertTrue(COOPER.account.supportsExecutionMode(mode));

		bytes memory callData = abi.encodeCall(MockTarget.emitEvent, (shouldRevert));
		bytes memory executionCalldata;
		address expectedSender;

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

		BUNDLER.handleOps(userOps);
	}

	function test_execute_revertsIfNotCalledByEntryPointOrSelf() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		bytes memory executionCalldata = abi.encodePacked(
			WNATIVE.toAddress(),
			DEFAULT_VALUE,
			abi.encodeWithSignature("deposit()")
		);

		vm.expectRevert(UnauthorizedCallContext.selector);
		COOPER.account.execute(mode, executionCalldata);

		vm.prank(COOPER.eoa);
		vm.expectRevert(UnauthorizedCallContext.selector);
		COOPER.account.execute(mode, executionCalldata);
	}

	function test_execute_transferNative() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertGe(address(COOPER.account).balance, DEFAULT_VALUE);
		assertEq(recipient.balance, 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(recipient, DEFAULT_VALUE, "");

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(recipient.balance, DEFAULT_VALUE);
	}

	function test_execute_transferERC20() public virtual {
		deal(USDC, address(COOPER.account), USDC_AMOUNT);
		assertEq(USDC.balanceOf(address(COOPER.account)), USDC_AMOUNT);
		assertEq(USDC.balanceOf(recipient), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			USDC.toAddress(),
			0,
			abi.encodeWithSignature("transfer(address,uint256)", recipient, USDC_AMOUNT)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(USDC.balanceOf(address(COOPER.account)), 0);
		assertEq(USDC.balanceOf(recipient), USDC_AMOUNT);
	}

	function test_executeSingle() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			WNATIVE.toAddress(),
			DEFAULT_VALUE,
			abi.encodeWithSignature("deposit()")
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), DEFAULT_VALUE);
	}

	function test_executeBatch() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(recipient), 0);

		Execution[] memory executions = new Execution[](2);

		executions[0] = Execution({
			target: WNATIVE.toAddress(),
			value: DEFAULT_VALUE,
			callData: abi.encodeWithSignature("deposit()")
		});

		executions[1] = Execution({
			target: WNATIVE.toAddress(),
			value: 0,
			callData: abi.encodeWithSignature("transfer(address,uint256)", recipient, DEFAULT_VALUE)
		});

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(EXECTYPE_DEFAULT.encodeExecutionCalldata(executions));

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(recipient), DEFAULT_VALUE);
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
				? abi.encodeCall(aux.mockExecutor.executeBatchViaAccount, (COOPER.account, executions))
				: abi.encodeCall(aux.mockExecutor.tryExecuteBatchViaAccount, (COOPER.account, executions));

			expectedValue = 2;
		} else if (callType == CALLTYPE_SINGLE) {
			executorCalldata = execType == EXECTYPE_DEFAULT
				? abi.encodeCall(aux.mockExecutor.executeViaAccount, (COOPER.account, address(MOCK), 0, callData))
				: abi.encodeCall(aux.mockExecutor.tryExecuteViaAccount, (COOPER.account, address(MOCK), 0, callData));

			expectedValue = 1;
		} else if (callType == CALLTYPE_DELEGATE) {
			executorCalldata = execType == EXECTYPE_DEFAULT
				? abi.encodeCall(aux.mockExecutor.executeDelegateViaAccount, (COOPER.account, address(MOCK), callData))
				: abi.encodeCall(
					aux.mockExecutor.tryExecuteDelegateViaAccount,
					(COOPER.account, address(MOCK), callData)
				);

			expectedValue = 0;
		}

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
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
			emit MockTarget.Incremented(address(aux.mockExecutor), 1, true);
		}

		BUNDLER.handleOps(userOps);
		assertEq(MOCK.getCounter(), expectedValue);
	}

	function test_executeFromExecutor_revertsIfCalledByInvalidExecutor() public virtual {
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(
				aux.mockExecutor.executeViaAccount,
				(MURPHY.account, address(MOCK), 0, abi.encodeCall(MockTarget.increment, ()))
			)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;
		(userOps[0], userOpHash) = MURPHY.prepareUserOp(executionCalldata);

		bytes memory revertReason = abi.encodeWithSelector(
			ModuleNotInstalled.selector,
			TYPE_EXECUTOR,
			aux.mockExecutor
		);

		vm.expectEmit(true, true, true, true);
		emit IEntryPoint.UserOperationRevertReason(userOpHash, address(MURPHY.account), userOps[0].nonce, revertReason);

		BUNDLER.handleOps(userOps);
	}

	function test_executeFromExecutor_transferNative() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertGe(address(COOPER.account).balance, DEFAULT_VALUE);
		assertEq(recipient.balance, 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(aux.mockExecutor.executeViaAccount, (COOPER.account, recipient, DEFAULT_VALUE, ""))
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(recipient.balance, DEFAULT_VALUE);
	}

	function test_executeFromExecutor_transferERC20() public virtual {
		deal(USDC, address(COOPER.account), USDC_AMOUNT);
		assertEq(USDC.balanceOf(address(COOPER.account)), USDC_AMOUNT);
		assertEq(USDC.balanceOf(recipient), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(
				aux.mockExecutor.executeViaAccount,
				(
					COOPER.account,
					USDC.toAddress(),
					0,
					abi.encodeWithSignature("transfer(address,uint256)", recipient, USDC_AMOUNT)
				)
			)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(USDC.balanceOf(recipient), USDC_AMOUNT);
	}

	function test_executeSingleFromExecutor() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), 0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(
				aux.mockExecutor.executeViaAccount,
				(COOPER.account, WNATIVE.toAddress(), DEFAULT_VALUE, abi.encodeWithSignature("deposit()"))
			)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(address(COOPER.account)), DEFAULT_VALUE);
	}

	function test_executeBatchFromExecutor() public virtual {
		deal(address(COOPER.account), address(COOPER.account).balance + DEFAULT_VALUE);
		assertEq(WNATIVE.balanceOf(recipient), 0);
		revertToState();

		Execution[] memory executions = new Execution[](2);

		executions[0] = Execution({
			target: WNATIVE.toAddress(),
			value: DEFAULT_VALUE,
			callData: abi.encodeWithSignature("deposit()")
		});

		executions[1] = Execution({
			target: WNATIVE.toAddress(),
			value: 0,
			callData: abi.encodeWithSignature("transfer(address,uint256)", recipient, DEFAULT_VALUE)
		});

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(aux.mockExecutor.executeBatchViaAccount, (COOPER.account, executions))
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(recipient), DEFAULT_VALUE);
		revertToState();

		bytes[] memory returnData = aux.mockExecutor.executeBatchViaAccount(COOPER.account, executions);
		assertEq(returnData.length, 2);
		assertEq(WNATIVE.balanceOf(recipient), DEFAULT_VALUE);
	}

	function test_executeBatchFromExecutorWithEmptyExecutions() public virtual {
		Execution[] memory executions = new Execution[](0);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(aux.mockExecutor),
			0,
			abi.encodeCall(aux.mockExecutor.executeBatchViaAccount, (COOPER.account, executions))
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = COOPER.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		bytes[] memory returnData = aux.mockExecutor.executeBatchViaAccount(COOPER.account, executions);
		assertEq(returnData.length, 0);
	}

	function test_isValidSignature_K1Validator() public virtual {
		bytes32 contents = keccak256("gravity equation");
		bytes32 contentsHash = MURPHY.account.hashTypedData(contents);

		address rootValidator = MURPHY.account.rootValidator();
		bytes memory innerSignature = toERC1271Signature(MURPHY, MURPHY.account, contents);

		bytes memory signature = abi.encodePacked(rootValidator, innerSignature);
		bytes memory wrappedSignature = abi.encodePacked(rootValidator, erc6492Wrap(innerSignature));

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
		assertEq(MURPHY.account.isValidSignature(contentsHash, wrappedSignature), ERC1271_SUCCESS);
	}

	function test_isValidSignature_ECDSAValidator() public virtual {
		bytes32 contents = keccak256("gargantua");
		bytes32 contentsHash = COOPER.account.hashTypedData(contents);

		address rootValidator = COOPER.account.rootValidator();
		bytes memory innerSignature = toERC1271Signature(COOPER, COOPER.account, contents);

		bytes memory signature = abi.encodePacked(rootValidator, innerSignature);
		// bytes memory wrappedSignature = abi.encodePacked(rootValidator, erc6492Wrap(innerSignature));

		assertEq(COOPER.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
		// assertEq(COOPER.account.isValidSignature(contentsHash, wrappedSignature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithInvalidSigner() public virtual {
		bytes32 contents = keccak256("gargantua");
		bytes32 contentsHash = MURPHY.account.hashTypedData(contents);

		bytes memory innerSignature = toERC1271Signature(COOPER, MURPHY.account, contents);
		bytes memory signature = abi.encodePacked(MURPHY.account.rootValidator(), innerSignature);

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_FAILED);
	}

	function test_isValidSignatureWithERC6492Unwrapping() public virtual {
		bytes32 contents = keccak256("gravity equation");
		bytes32 contentsHash = MURPHY.account.hashTypedData(contents);

		bytes memory innerSignature = toERC1271Signature(MURPHY, MURPHY.account, contents);
		bytes memory signature = abi.encodePacked(MURPHY.account.rootValidator(), erc6492Wrap(innerSignature));

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithoutERC6492Unwrapping() public virtual {
		bytes32 contents = keccak256("gravity equation");
		bytes32 contentsHash = MURPHY.account.hashTypedData(contents);

		bytes memory innerSignature = toERC1271Signature(MURPHY, MURPHY.account, contents);
		bytes memory signature = abi.encodePacked(MURPHY.account.rootValidator(), innerSignature);

		assertEq(MURPHY.account.isValidSignature(contentsHash, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithERC7739() public virtual asEntryPoint {
		assertEq(ALICE.account.isValidSignature(ERC7793_TYPEHASH, ""), ERC7739_SUPPORTS_V1);
	}

	function test_isValidSignatureWithPersonalSign_K1Validator() public virtual {
		bytes32 contents = keccak256("wonderland");
		bytes32 structHash = keccak256(abi.encode(keccak256("PersonalSign(bytes prefixed)"), contents));
		bytes32 messageHash = ALICE.account.hashTypedData(structHash);

		bytes memory innerSignature = ALICE.sign(messageHash);
		bytes memory signature = abi.encodePacked(aux.k1Validator, innerSignature);

		assertEq(ALICE.account.isValidSignature(contents, signature), ERC1271_SUCCESS);
	}

	function test_isValidSignatureWithPersonalSign_ECDSAValidator() public virtual {
		bytes32 contents = keccak256("gargantua");
		bytes32 structHash = keccak256(abi.encode(keccak256("PersonalSign(bytes prefixed)"), contents));
		bytes32 messageHash = COOPER.account.hashTypedData(structHash);

		bytes memory innerSignature = COOPER.sign(messageHash);
		bytes memory signature = abi.encodePacked(aux.ecdsaValidator, innerSignature);

		assertEq(COOPER.account.isValidSignature(contents, signature), ERC1271_SUCCESS);
	}

	function toERC1271Signature(
		Signer memory signer,
		Vortex account,
		bytes32 contents
	) internal view virtual returns (bytes memory signature) {
		bytes memory contentsType = "Contents(bytes32 hash)";

		bytes32 typehash = keccak256(
			abi.encodePacked(
				"TypedDataSign(Contents contents,string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)",
				contentsType
			)
		);

		bytes32 structHash = keccak256(
			abi.encodePacked(abi.encode(typehash, contents), getAccountDomainStructFields(account))
		);

		bytes32 messageHash = account.hashTypedData(structHash);

		signature = abi.encodePacked(
			signer.sign(messageHash),
			account.DOMAIN_SEPARATOR(),
			contents,
			contentsType,
			uint16(contentsType.length)
		);
	}

	function erc6492Wrap(bytes memory signature) internal virtual returns (bytes memory) {
		return abi.encodePacked(abi.encode(randomAddress(), bytes(randomString("12345")), signature), ERC6492_TYPEHASH);
	}

	function validateAccountCreation(Vortex account, address owner) internal view virtual {
		assertContract(address(account));
		assertEq(bytes32ToAddress(vm.load(address(account), ERC1967_IMPLEMENTATION_SLOT)), address(aux.vortex));
		assertEq(account.implementation(), address(aux.vortex));

		(
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainId,
			address verifyingContract,
			,

		) = account.eip712Domain();

		assertEq(account.accountId(), "fomoweth.vortex.1.0.0");
		assertEq(fields, hex"0f");
		assertEq(name, "Vortex");
		assertEq(version, "1.0.0");
		assertEq(chainId, block.chainid);
		assertEq(verifyingContract, address(account));

		assertEq(account.registry(), owner != MURPHY.eoa ? address(REGISTRY) : address(0));
		assertEq(account.rootValidator(), owner != COOPER.eoa ? address(aux.k1Validator) : address(aux.ecdsaValidator));

		assertTrue(
			!account.supportsModule(TYPE_MULTI) &&
				account.supportsModule(TYPE_VALIDATOR) &&
				account.supportsModule(TYPE_EXECUTOR) &&
				account.supportsModule(TYPE_FALLBACK) &&
				account.supportsModule(TYPE_HOOK) &&
				!account.supportsModule(TYPE_POLICY) &&
				!account.supportsModule(TYPE_SIGNER) &&
				account.supportsModule(TYPE_STATELESS_VALIDATOR) &&
				account.supportsModule(TYPE_PREVALIDATION_HOOK_ERC1271) &&
				account.supportsModule(TYPE_PREVALIDATION_HOOK_ERC4337)
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_SINGLE, EXECTYPE_DEFAULT)) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_SINGLE, EXECTYPE_TRY))
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_BATCH, EXECTYPE_DEFAULT)) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_BATCH, EXECTYPE_TRY))
		);

		assertTrue(
			account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_DELEGATE, EXECTYPE_DEFAULT)) &&
				account.supportsExecutionMode(ExecutionModeLib.encodeCustom(CALLTYPE_DELEGATE, EXECTYPE_TRY))
		);
	}
}
