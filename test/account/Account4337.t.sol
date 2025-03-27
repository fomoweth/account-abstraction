// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/env/BaseTest.sol";

contract Account4337Test is BaseTest {
	address internal immutable recipient = makeAddr("RECIPIENT");

	function setUp() public virtual override {
		super.setUp();
		deployVortex(MURPHY, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), false);
	}

	function test_addDeposit() public virtual {
		uint256 deposit = MURPHY.account.getDeposit();

		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(MURPHY.account.getDeposit(), deposit + DEFAULT_VALUE);
	}

	function test_withdrawTo() public virtual {
		address target = address(MURPHY.account);
		bytes memory callData = abi.encodeCall(MURPHY.account.withdrawTo, (recipient, DEFAULT_VALUE));

		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(recipient.balance, 0);

		MURPHY.execute(EXECTYPE_DEFAULT, target, 0, callData);
		assertEq(recipient.balance, DEFAULT_VALUE);
	}

	function test_withdrawTo_revertsIfNotCalledByEntryPointOrSelf() public virtual {
		uint256 deposit = MURPHY.account.getDeposit();

		MURPHY.account.addDeposit{value: DEFAULT_VALUE}();
		assertEq(MURPHY.account.getDeposit(), deposit + DEFAULT_VALUE);

		vm.expectRevert(UnauthorizedCallContext.selector);
		MURPHY.account.withdrawTo(recipient, DEFAULT_VALUE);

		vm.expectRevert(UnauthorizedCallContext.selector);
		vm.prank(MURPHY.eoa);
		MURPHY.account.withdrawTo(recipient, DEFAULT_VALUE);
	}

	function test_getNonce() public virtual {
		uint192 nonceKey = VALIDATION_MODE_DEFAULT.encodeNonceKey(MURPHY.account.rootValidator());
		assertEq(MURPHY.account.getNonce(nonceKey), ENTRYPOINT.getNonce(address(MURPHY.account), nonceKey));

		nonceKey = VALIDATION_MODE_ENABLE.encodeNonceKey(MURPHY.account.rootValidator());
		assertEq(MURPHY.account.getNonce(nonceKey), ENTRYPOINT.getNonce(address(MURPHY.account), nonceKey));
	}
}
