// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Vortex} from "src/Vortex.sol";
import {FactoryTest} from "./FactoryTest.sol";

contract VortexFactoryTest is FactoryTest {
	function setUp() public virtual override {
		super.setUp();
		setInitializerFlag(INITIALIZER_ROOT);
	}

	function test_deployment() public virtual {
		assertEq(VORTEX_FACTORY.ACCOUNT_IMPLEMENTATION(), address(ACCOUNT_IMPLEMENTATION));
		assertEq(VORTEX_FACTORY.K1_VALIDATOR(), address(K1_VALIDATOR));
		assertEq(VORTEX_FACTORY.BOOTSTRAP(), address(BOOTSTRAP));
		assertEq(VORTEX_FACTORY.REGISTRY(), address(REGISTRY));
	}

	function test_createAccount_revertsWithInvalidEOAOwner() public virtual {
		bytes32 salt = encodeSalt(address(this), 0);
		bytes memory data = abi.encode(address(this), SENDER_ADDRESSES, ATTESTER_ADDRESSES, THRESHOLD);

		expectRevert(InvalidEOAOwner.selector);
		VORTEX_FACTORY.createAccount{value: INITIAL_VALUE}(salt, data);
	}

	function test_createAccount_revertsWithInvalidThreshold() public virtual impersonate(ALICE_ADDRESS) {
		bytes32 salt = encodeSalt(ALICE_ADDRESS, 0);
		bytes memory data = abi.encode(ALICE_ADDRESS, SENDER_ADDRESSES, ATTESTER_ADDRESSES, ATTESTERS_COUNT + 1);

		expectRevert(InvalidThreshold.selector);
		VORTEX_FACTORY.createAccount{value: INITIAL_VALUE}(salt, data);
	}

	function test_createAccount(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		(address payable predicted, bytes memory initCode, bytes32 salt) = getAccountAndInitCode(
			ALICE,
			index,
			address(VORTEX_FACTORY),
			false
		);

		address payable account = VORTEX_FACTORY.createAccount{value: INITIAL_VALUE}(salt, initCode);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountWithParameters(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		bytes32 salt = encodeSalt(ALICE_ADDRESS, index);

		address payable predicted = VORTEX_FACTORY.computeAddress(salt);

		address payable account = VORTEX_FACTORY.createAccount{value: INITIAL_VALUE}(
			salt,
			ALICE_ADDRESS,
			SENDER_ADDRESSES,
			ATTESTER_ADDRESSES,
			THRESHOLD
		);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountViaMetaFactory(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		(address payable predicted, bytes memory initCode, ) = getAccountAndInitCode(
			ALICE,
			index,
			address(VORTEX_FACTORY),
			true
		);

		address payable account = META_FACTORY.createAccount{value: INITIAL_VALUE}(initCode);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountViaEntryPoint(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		(address payable account, bytes memory initCode, ) = getAccountAndInitCode(
			ALICE,
			index,
			address(VORTEX_FACTORY),
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
