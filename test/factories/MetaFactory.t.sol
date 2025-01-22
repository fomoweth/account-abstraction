// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";

contract MetaFactoryTest is BaseTest {
	uint256 internal constant STAKE_AMOUNT = 10 ether;
	uint32 internal constant UNSTAKE_DELAY = 1 weeks;

	Signer internal RECIPIENT;
	address payable internal RECIPIENT_ADDRESS;

	function setUp() public virtual override {
		super.setUp();

		RECIPIENT = createSigner("RECIPIENT", 0);
		RECIPIENT_ADDRESS = RECIPIENT.addr;
	}

	function setUpContracts() internal virtual override {
		deployAccountImplementation();
		deployRegistry();
		deployFactories();
		deployModules();
	}

	function test_deployment() public virtual {
		assertEq(META_FACTORY.owner(), DEPLOYER_ADDRESS);
	}

	function test_setApproval_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);
	}

	function test_setApproval_revertsWithInvalidFactory() public virtual impersonate(DEPLOYER_ADDRESS) {
		vm.expectRevert(InvalidFactory.selector);
		META_FACTORY.setWhitelist(address(0), true);
	}

	function test_setApproval() public virtual impersonate(DEPLOYER_ADDRESS) {
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

	function test_addStake_revertsWithInvalidEntryPoint() public virtual impersonate(DEPLOYER_ADDRESS) {
		vm.expectRevert(InvalidEntryPoint.selector);
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(0), UNSTAKE_DELAY);
	}

	function test_addStake(uint256 stakeAmount, uint32 unstakeDelaySec) public virtual impersonate(DEPLOYER_ADDRESS) {
		vm.assume(stakeAmount > 0 && stakeAmount <= 1000 ether);
		vm.assume(unstakeDelaySec > 0);

		deal(DEPLOYER_ADDRESS, stakeAmount);

		expectEmitStakeLocked(address(META_FACTORY), stakeAmount, unstakeDelaySec);
		META_FACTORY.addStake{value: stakeAmount}(address(ENTRYPOINT), unstakeDelaySec);
	}

	function test_unlockStake_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.unlockStake(address(ENTRYPOINT));
	}

	function test_unlockStake_revertsWithInvalidEntryPoint() public virtual impersonate(DEPLOYER_ADDRESS) {
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);
		vm.warp(vm.getBlockTimestamp() + UNSTAKE_DELAY);

		vm.expectRevert(InvalidEntryPoint.selector);
		META_FACTORY.unlockStake(address(0));
	}

	function test_unlockStake() public virtual impersonate(DEPLOYER_ADDRESS) {
		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);

		uint48 withdrawTime = uint48(block.timestamp) + UNSTAKE_DELAY;
		expectEmitStakeUnlocked(address(META_FACTORY), withdrawTime);
		META_FACTORY.unlockStake(address(ENTRYPOINT));
	}

	function test_withdrawStake_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), RECIPIENT_ADDRESS);
	}

	function test_withdrawStake_revertsWithInvalidEntryPoint() public virtual impersonate(DEPLOYER_ADDRESS) {
		vm.expectRevert(InvalidEntryPoint.selector);
		META_FACTORY.withdrawStake(address(0), RECIPIENT_ADDRESS);
	}

	function test_withdrawStake_revertsWithInvalidRecipient() public virtual impersonate(DEPLOYER_ADDRESS) {
		vm.expectRevert(InvalidRecipient.selector);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), address(0));
	}

	function test_withdrawStake() public virtual impersonate(DEPLOYER_ADDRESS) {
		assertEq(RECIPIENT_ADDRESS.balance, 0);

		META_FACTORY.addStake{value: STAKE_AMOUNT}(address(ENTRYPOINT), UNSTAKE_DELAY);

		META_FACTORY.unlockStake(address(ENTRYPOINT));

		vm.warp(vm.getBlockTimestamp() + UNSTAKE_DELAY);

		expectEmitStakeWithdrawn(address(META_FACTORY), RECIPIENT_ADDRESS, STAKE_AMOUNT);
		META_FACTORY.withdrawStake(address(ENTRYPOINT), RECIPIENT_ADDRESS);

		assertEq(RECIPIENT_ADDRESS.balance, STAKE_AMOUNT);
	}

	function test_createAccount_revertsWithFactoryNotApproved() public virtual {
		assertFalse(META_FACTORY.isWhitelisted(address(ACCOUNT_FACTORY)));

		(, bytes memory initCode) = getAccountAndInitCode(ALICE, DEFAULT_SALT, address(ACCOUNT_FACTORY));

		expectRevertFactoryNotWhitelisted(address(ACCOUNT_FACTORY));
		META_FACTORY.createAccount(initCode);
	}

	function test_createAccount_revertsWithInvalidDataLength() public virtual {
		vm.prank(DEPLOYER_ADDRESS);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);

		expectRevertInvalidDataLength();
		META_FACTORY.createAccount(abi.encodePacked(ACCOUNT_FACTORY));

		expectRevertInvalidDataLength();
		META_FACTORY.createAccount(emptyBytes());
	}

	function test_createAccount() public virtual {
		vm.prank(DEPLOYER_ADDRESS);
		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);

		(address payable account, bytes memory initCode) = getAccountAndInitCode(
			ALICE,
			DEFAULT_SALT,
			address(ACCOUNT_FACTORY)
		);

		vm.prank(ALICE_ADDRESS);
		address payable deployed = META_FACTORY.createAccount{value: INITIAL_DEPOSIT}(initCode);

		assertEq(deployed, account);
	}
}
