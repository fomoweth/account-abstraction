// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Vortex} from "src/Vortex.sol";
import {FactoryTest} from "./FactoryTest.sol";

contract AccountFactoryTest is FactoryTest {
	function test_deployment() public virtual {
		assertEq(ACCOUNT_FACTORY.ACCOUNT_IMPLEMENTATION(), address(ACCOUNT_IMPLEMENTATION));
	}

	function test_createAccount(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		setInitializer(index);

		(address payable predicted, bytes memory initCode, bytes32 salt) = getAccountAndInitCode(
			ALICE,
			index,
			address(ACCOUNT_FACTORY),
			false
		);

		address payable account = ACCOUNT_FACTORY.createAccount{value: INITIAL_VALUE}(salt, initCode);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountViaMetaFactory(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		setInitializer(index);

		(address payable predicted, bytes memory initCode, ) = getAccountAndInitCode(
			ALICE,
			index,
			address(ACCOUNT_FACTORY),
			true
		);

		address payable account = META_FACTORY.createAccount{value: INITIAL_VALUE}(initCode);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountViaEntryPoint(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		setInitializer(index);

		(address payable account, bytes memory initCode, ) = getAccountAndInitCode(
			ALICE,
			index,
			address(ACCOUNT_FACTORY),
			true
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = ALICE.buildUserOp(account, initCode, emptyBytes(), emptyBytes(), address(K1_VALIDATOR));

		ENTRYPOINT.depositTo{value: INITIAL_VALUE}(account);
		ENTRYPOINT.handleOps(userOps, ALICE_ADDRESS);

		assertApproxEqAbs(ENTRYPOINT.balanceOf(account), INITIAL_VALUE, 0.0001e18);
		validateDeployment(Vortex(account));
	}
}
