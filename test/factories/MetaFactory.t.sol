// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Vortex} from "src/Vortex.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {FactoryTest} from "./FactoryTest.sol";

contract MetaFactory is FactoryTest {
	uint256 internal constant STAKE_AMOUNT = 10 ether;
	uint32 internal constant UNSTAKE_DELAY = 1 weeks;

	function setUp() public virtual override {
		super.setUp();
	}

	function setUpContracts() internal virtual override {
		deployContracts();
		setUpModules();
	}

	function test_deployment() public virtual {
		assertEq(META_FACTORY.owner(), ADMIN_ADDRESS);
	}

	function test_createAccount() public virtual {
		setUpFactories();

		address[] memory factories = SolArray.addresses(
			address(ACCOUNT_FACTORY),
			address(VORTEX_FACTORY),
			address(REGISTRY_FACTORY)
		);

		vm.startPrank(ALICE_ADDRESS);

		revertToState();

		address payable predicted;
		address payable account;
		bytes memory initCode;

		for (uint256 i; i < factories.length; ++i) {
			if (factories[i] == address(VORTEX_FACTORY)) setInitializerFlag(INITIALIZER_ROOT);
			else setInitializerFlag(INITIALIZER_DEFAULT);

			(predicted, initCode, ) = getAccountAndInitCode(ALICE, 0, factories[i], true);
			assertFalse(isContract(predicted));

			account = META_FACTORY.createAccount{value: INITIAL_VALUE}(initCode);

			assertEq(account, predicted);
			assertEq(account.balance, INITIAL_VALUE);
			validateDeployment(Vortex(account));

			revertToState();
		}

		vm.stopPrank();
	}

	function test_createAccountViaEntryPoint() public virtual {
		setUpFactories();

		address[] memory factories = SolArray.addresses(
			address(ACCOUNT_FACTORY),
			address(VORTEX_FACTORY),
			address(REGISTRY_FACTORY)
		);

		vm.startPrank(ALICE_ADDRESS);

		revertToState();

		address payable account;
		bytes memory initCode;

		for (uint256 i; i < factories.length; ++i) {
			if (factories[i] == address(VORTEX_FACTORY)) setInitializerFlag(INITIALIZER_ROOT);
			else setInitializerFlag(INITIALIZER_DEFAULT);

			(account, initCode, ) = getAccountAndInitCode(ALICE, 0, factories[i], true);
			assertFalse(isContract(account));

			PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
			userOps[0] = ALICE.buildUserOp(account, initCode, emptyBytes(), emptyBytes(), address(K1_VALIDATOR));

			ENTRYPOINT.depositTo{value: INITIAL_VALUE}(account);
			ENTRYPOINT.handleOps(userOps, ALICE_ADDRESS);

			assertApproxEqAbs(ENTRYPOINT.balanceOf(account), INITIAL_VALUE, 0.0001e18);
			validateDeployment(Vortex(account));

			revertToState();
		}

		vm.stopPrank();
	}

	function test_createAccount_revertsWithFactoryNotApproved() public virtual {
		assertFalse(META_FACTORY.isWhitelisted(address(ACCOUNT_FACTORY)));

		(, bytes memory initCode, ) = getAccountAndInitCode(ALICE, 0, address(ACCOUNT_FACTORY), true);

		vm.expectRevert(abi.encodeWithSelector(FactoryNotWhitelisted.selector, address(ACCOUNT_FACTORY)));
		META_FACTORY.createAccount(initCode);
	}

	function test_createAccount_revertsWithInvalidDataLength() public virtual {
		vm.prank(ADMIN_ADDRESS);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);

		vm.expectRevert(InvalidDataLength.selector);
		META_FACTORY.createAccount(abi.encodePacked(ACCOUNT_FACTORY));

		vm.expectRevert(InvalidDataLength.selector);
		META_FACTORY.createAccount(emptyBytes());
	}

	function test_setApproval_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);
	}

	function test_setApproval_revertsWithInvalidFactory() public virtual impersonate(ADMIN_ADDRESS) {
		vm.expectRevert(InvalidFactory.selector);
		META_FACTORY.setWhitelist(ZERO, true);
	}

	function test_setApproval() public virtual impersonate(ADMIN_ADDRESS) {
		assertFalse(META_FACTORY.isWhitelisted(address(ACCOUNT_FACTORY)));

		expectEmitWhitelistSet(address(ACCOUNT_FACTORY), true);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);

		assertTrue(META_FACTORY.isWhitelisted(address(ACCOUNT_FACTORY)));

		expectEmitWhitelistSet(address(ACCOUNT_FACTORY), false);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), false);

		assertFalse(META_FACTORY.isWhitelisted(address(ACCOUNT_FACTORY)));
	}

	function test_addStake_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);
	}

	function test_addStake_revertsWithInvalidEntryPoint() public virtual impersonate(ADMIN_ADDRESS) {
		vm.expectRevert();
		META_FACTORY.addStake{value: STAKE_AMOUNT}(ZERO, UNSTAKE_DELAY);
	}

	function test_addStake(uint256 stakeAmount, uint32 unstakeDelaySec) public virtual impersonate(ADMIN_ADDRESS) {
		vm.assume(stakeAmount > 0 && stakeAmount <= 1000 ether);
		vm.assume(unstakeDelaySec > 0);

		expectEmitStakeLocked(address(META_FACTORY), stakeAmount, unstakeDelaySec);
		META_FACTORY.addStake{value: stakeAmount}(address(ENTRYPOINT), unstakeDelaySec);
	}

	function test_unlockStake_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.unlockStake(address(ENTRYPOINT));
	}

	function test_unlockStake_revertsWithInvalidEntryPoint() public virtual impersonate(ADMIN_ADDRESS) {
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);
		vm.warp(vm.getBlockTimestamp() + UNSTAKE_DELAY);

		vm.expectRevert();
		META_FACTORY.unlockStake(ZERO);
	}

	function test_unlockStake() public virtual impersonate(ADMIN_ADDRESS) {
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);

		uint48 withdrawTime = uint48(block.timestamp) + UNSTAKE_DELAY;
		expectEmitStakeUnlocked(address(META_FACTORY), withdrawTime);
		META_FACTORY.unlockStake(address(ENTRYPOINT));
	}

	function test_withdrawStake_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), BENEFICIARY_ADDRESS);
	}

	function test_withdrawStake_revertsWithInvalidEntryPoint() public virtual impersonate(ADMIN_ADDRESS) {
		vm.expectRevert();
		META_FACTORY.withdrawStake(ZERO, BENEFICIARY_ADDRESS);
	}

	function test_withdrawStake_revertsWithInvalidRecipient() public virtual impersonate(ADMIN_ADDRESS) {
		vm.expectRevert(InvalidRecipient.selector);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), ZERO);
	}

	function test_withdrawStake() public virtual impersonate(ADMIN_ADDRESS) {
		assertEq(BENEFICIARY_ADDRESS.balance, 0);

		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);

		META_FACTORY.unlockStake(address(ENTRYPOINT));

		vm.warp(vm.getBlockTimestamp() + UNSTAKE_DELAY);

		expectEmitStakeWithdrawn(address(META_FACTORY), BENEFICIARY_ADDRESS, STAKE_AMOUNT);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), BENEFICIARY_ADDRESS);

		assertEq(BENEFICIARY_ADDRESS.balance, STAKE_AMOUNT);
	}
}
