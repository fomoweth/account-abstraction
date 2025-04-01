// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IStakeManager} from "account-abstraction/interfaces/IStakeManager.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UUPSUpgradeable} from "src/utils/UUPSUpgradeable.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {VortexV2} from "test/shared/mocks/VortexV2.sol";
import {ExecutionUtils, ExecType} from "test/shared/utils/ExecutionUtils.sol";

contract Account4337Test is BaseTest {
	using ExecutionUtils for ExecType;

	address internal constant ENTRYPOINT_V8 = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

	address internal immutable recipient = makeAddr("RECIPIENT");

	VortexV2 internal VORTEX_V2;

	function setUp() public virtual override {
		super.setUp();
		deployVortex(MURPHY, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), false);
		VORTEX_V2 = new VortexV2();
	}

	function test_addDeposit() public virtual {
		uint256 deposit = MURPHY.account.getDeposit();
		uint256 totalDeposit = deposit + DEFAULT_VALUE;

		revertToState();

		vm.expectEmit(true, true, true, true, address(ENTRYPOINT));
		emit IStakeManager.Deposited(address(MURPHY.account), totalDeposit);

		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(MURPHY.account.getDeposit(), totalDeposit);

		revertToState();

		deal(address(MURPHY.account), DEFAULT_VALUE);
		assertEq(MURPHY.account.getDeposit(), deposit);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			address(MURPHY.account),
			DEFAULT_VALUE,
			abi.encodeCall(MURPHY.account.addDeposit, ())
		);

		vm.recordLogs();

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;
		(userOps[0], userOpHash) = MURPHY.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		(bool success, , uint256 actualGasUsed, ) = parseUserOpResult(userOpHash, vm.getRecordedLogs());

		assertTrue(success);
		assertGe(MURPHY.account.getDeposit(), totalDeposit - actualGasUsed);
	}

	function test_withdrawTo() public virtual {
		assertEq(recipient.balance, 0);

		uint256 deposit = MURPHY.account.getDeposit();
		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(MURPHY.account.getDeposit(), deposit + DEFAULT_VALUE);

		bytes memory callData = abi.encodeCall(MURPHY.account.withdrawTo, (recipient, DEFAULT_VALUE));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);

		vm.expectEmit(true, true, true, true, address(ENTRYPOINT));
		emit IStakeManager.Withdrawn(address(MURPHY.account), recipient, DEFAULT_VALUE);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(recipient.balance, DEFAULT_VALUE);
	}

	function test_withdrawTo_revertsIfNotCalledByEntryPointOrSelf() public virtual {
		uint256 deposit = MURPHY.account.getDeposit();
		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(MURPHY.account.getDeposit(), deposit + DEFAULT_VALUE);

		vm.expectRevert(UnauthorizedCallContext.selector);
		MURPHY.account.withdrawTo(recipient, DEFAULT_VALUE);

		vm.prank(MURPHY.eoa);
		vm.expectRevert(UnauthorizedCallContext.selector);
		MURPHY.account.withdrawTo(recipient, DEFAULT_VALUE);
	}

	function test_getNonce() public virtual {
		uint192 nonceKey = VALIDATION_MODE_DEFAULT.encodeNonceKey(MURPHY.account.rootValidator());
		assertEq(MURPHY.account.getNonce(nonceKey), ENTRYPOINT.getNonce(address(MURPHY.account), nonceKey));

		nonceKey = VALIDATION_MODE_ENABLE.encodeNonceKey(MURPHY.account.rootValidator());
		assertEq(MURPHY.account.getNonce(nonceKey), ENTRYPOINT.getNonce(address(MURPHY.account), nonceKey));
	}

	function test_upgradeToAndCall() public virtual {
		assertEq(bytes32ToAddress(vm.load(address(MURPHY.account), ERC1967_IMPLEMENTATION_SLOT)), address(VORTEX));
		assertEq(MURPHY.account.implementation(), address(VORTEX));
		assertEq(MURPHY.account.accountId(), "fomoweth.vortex.1.0.0");
		assertEq(MURPHY.account.entryPoint(), address(ENTRYPOINT));
		assertEq(MURPHY.account.rootValidator(), address(K1_VALIDATOR));

		bytes memory callData = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(VORTEX_V2), ""));

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);

		vm.expectEmit(true, true, true, true, address(MURPHY.account));
		emit Upgraded(address(VORTEX_V2));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);

		assertEq(bytes32ToAddress(vm.load(address(MURPHY.account), ERC1967_IMPLEMENTATION_SLOT)), address(VORTEX_V2));
		assertEq(MURPHY.account.implementation(), address(VORTEX_V2));
		assertEq(MURPHY.account.accountId(), "fomoweth.vortex.2.0.0");
		assertEq(MURPHY.account.entryPoint(), ENTRYPOINT_V8);
		assertEq(MURPHY.account.rootValidator(), address(K1_VALIDATOR));
	}

	function test_upgradeToAndCall_revertsIfImplementationNotValid() public virtual {
		bytes memory revertReason = abi.encodeWithSelector(InvalidImplementation.selector);
		bytes memory callData = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(0), ""));
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;
		(userOps[0], userOpHash) = MURPHY.prepareUserOp(executionCalldata);

		vm.expectEmit(true, true, true, true, address(ENTRYPOINT));
		emit IEntryPoint.UserOperationRevertReason(userOpHash, address(MURPHY.account), userOps[0].nonce, revertReason);

		BUNDLER.handleOps(userOps);
	}

	function test_upgradeToAndCall_revertsIfNotCalledByEntryPointOrSelf() public virtual {
		vm.expectRevert(UnauthorizedCallContext.selector);
		MURPHY.account.upgradeToAndCall(address(VORTEX_V2), "");

		vm.prank(MURPHY.eoa);
		vm.expectRevert(UnauthorizedCallContext.selector);
		MURPHY.account.upgradeToAndCall(address(VORTEX_V2), "");
	}
}
