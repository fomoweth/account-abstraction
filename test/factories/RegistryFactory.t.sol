// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {Vortex} from "src/Vortex.sol";
import {FactoryTest} from "./FactoryTest.sol";

contract RegistryFactoryTest is FactoryTest {
	function setUp() public virtual override {
		super.setUp();
		setInitializerFlag(INITIALIZER_DEFAULT);
	}

	function test_deployment() public virtual {
		assertEq(REGISTRY_FACTORY.ACCOUNT_IMPLEMENTATION(), address(ACCOUNT_IMPLEMENTATION));
		assertEq(REGISTRY_FACTORY.REGISTRY(), address(REGISTRY));
		assertEq(REGISTRY_FACTORY.owner(), ADMIN_ADDRESS);
		assertEq(REGISTRY_FACTORY.getThreshold(), THRESHOLD);
		assertEq(REGISTRY_FACTORY.getAttestersLength(), ATTESTERS_COUNT);
		assertEq(REGISTRY_FACTORY.getAttesters(), ATTESTER_ADDRESSES);

		for (uint256 i; i < ATTESTERS_COUNT; ++i) {
			assertTrue(REGISTRY_FACTORY.isAuthorized(ATTESTER_ADDRESSES[i]));
		}
	}

	function test_deployment_revertsWithInvalidAttester() public virtual {
		address[] memory attesters = new address[](2);
		attesters[0] = address(0);
		attesters[1] = address(1);

		expectRevert(InvalidAttester.selector);
		new RegistryFactory(address(ACCOUNT_IMPLEMENTATION), address(REGISTRY), attesters, 1, ADMIN_ADDRESS);
	}

	function test_deployment_revertsWithAttestersNotSorted() public virtual {
		address[] memory attesters = new address[](3);
		attesters[0] = address(1);
		attesters[1] = address(3);
		attesters[2] = address(2);

		expectRevert(AttestersNotSorted.selector);
		new RegistryFactory(address(ACCOUNT_IMPLEMENTATION), address(REGISTRY), attesters, 2, ADMIN_ADDRESS);
	}

	function test_configureAttesters_revertsWithInvalidThreshold() public virtual impersonate(ADMIN_ADDRESS) {
		address[] memory attesters = new address[](2);
		attesters[0] = address(1);
		attesters[1] = address(2);

		expectRevert(InvalidThreshold.selector);
		REGISTRY_FACTORY.configureAttesters(attesters, 0);

		expectRevert(InvalidThreshold.selector);
		REGISTRY_FACTORY.configureAttesters(attesters, uint8(attesters.length + 1));
	}

	function test_configureAttesters() public virtual impersonate(ADMIN_ADDRESS) {
		uint8 threshold = THRESHOLD + 1;

		(, address[] memory attesters) = createUsers("Attester", threshold + 1, INITIAL_BALANCE);

		REGISTRY_FACTORY.configureAttesters(attesters, threshold);

		assertEq(threshold, REGISTRY_FACTORY.getThreshold());
		assertEq(attesters, REGISTRY_FACTORY.getAttesters());

		for (uint256 i; i < attesters.length; ++i) {
			assertTrue(REGISTRY_FACTORY.isAuthorized(attesters[i]));
		}
	}

	function test_createAccount(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		(address payable predicted, bytes memory initCode, bytes32 salt) = getAccountAndInitCode(
			ALICE,
			index,
			address(REGISTRY_FACTORY),
			false
		);

		address payable account = REGISTRY_FACTORY.createAccount{value: INITIAL_VALUE}(salt, initCode);

		assertEq(account, predicted);
		assertEq(account.balance, INITIAL_VALUE);
		validateDeployment(Vortex(account));
	}

	function test_createAccountViaMetaFactory(uint8 index) public virtual impersonate(ALICE_ADDRESS) {
		(address payable predicted, bytes memory initCode, ) = getAccountAndInitCode(
			ALICE,
			index,
			address(REGISTRY_FACTORY),
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
			address(REGISTRY_FACTORY),
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
