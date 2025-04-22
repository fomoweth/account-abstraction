// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IStakeManager} from "account-abstraction/interfaces/IStakeManager.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Arrays} from "src/libraries/Arrays.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {ExecutionUtils, ExecType} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract RegistryFactoryTest is BaseTest {
	using Arrays for address[];
	using SolArray for address;

	error AttesterAlreadyExists(address attester);
	error AttesterNotExists(address attester);
	error ExceededMaxAttesters();
	error InvalidTrustedAttesters();
	error InvalidAttester();
	error InvalidThreshold();
	error ModuleNotAuthorized(address module);

	uint256 internal key = encodePrivateKey("Attester");

	function setUp() public virtual override {
		super.setUp();
	}

	function setUpFactories() internal virtual override impersonate(ADMIN, false) {
		aux.metaFactory.stake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_DELAY);
		aux.metaFactory.authorize(address(aux.registryFactory));
	}

	function test_configureAttestations() public virtual impersonate(ADMIN, false) {
		uint8 threshold = 5;
		address[] memory attesters = prepareAttesters(threshold, false);

		aux.registryFactory.configure(attesters, threshold);
		assertEq(attesters, aux.registryFactory.getTrustedAttesters());
	}

	function test_configureAttestations_revertsWithUnauthorized() public virtual {
		vm.expectRevert(Unauthorized.selector);
		aux.registryFactory.configure(prepareAttesters(5, false), 1);
	}

	function test_configureAttestations_revertsWithInvalidAttesters() public virtual impersonate(ADMIN, false) {
		address[] memory attesters = address(0).addresses(ALICE.eoa, COOPER.eoa, MURPHY.eoa);

		vm.expectRevert(InvalidTrustedAttesters.selector);
		aux.registryFactory.configure(attesters, 1);
	}

	function test_configureAttestations_revertsWithExceededMaxAttesters() public virtual impersonate(ADMIN, false) {
		uint8 threshold = 33;
		address[] memory attesters = prepareAttesters(threshold, false);

		vm.expectRevert(ExceededMaxAttesters.selector);
		aux.registryFactory.configure(attesters, threshold);
	}

	function test_addAttester() public virtual impersonate(ADMIN, false) {
		uint256 length = 5;
		address[] memory attesters = prepareAttesters(length, false);

		aux.registryFactory.configure(attesters[0].addresses(), 1);

		for (uint256 i = 1; i < length; ++i) {
			aux.registryFactory.authorize(attesters[i]);
			assertTrue(aux.registryFactory.isAuthorized(attesters[i]));
		}

		attesters.insertionSort();
		attesters.uniquifySorted();
		assertEq(attesters, aux.registryFactory.getTrustedAttesters());
	}

	function test_addAttester_revertsWithUnauthorized() public virtual {
		vm.prank(ADMIN.eoa);
		aux.registryFactory.configure(prepareAttesters(1, true), 1);

		vm.expectRevert(Unauthorized.selector);
		aux.registryFactory.authorize(ALICE.eoa);

		vm.expectRevert(Unauthorized.selector);
		aux.registryFactory.authorize(COOPER.eoa);

		vm.expectRevert(Unauthorized.selector);
		aux.registryFactory.authorize(MURPHY.eoa);
	}

	function test_addAttester_revertsWithInvalidAttesters() public virtual impersonate(ADMIN, false) {
		aux.registryFactory.configure(prepareAttesters(2, false), 1);

		vm.expectRevert(InvalidAttester.selector);
		aux.registryFactory.authorize(address(0));
	}

	function test_addAttester_revertsWithAttesterAlreadyExists() public virtual impersonate(ADMIN, false) {
		uint256 length = 5;
		address[] memory attesters = prepareAttesters(length, true);
		aux.registryFactory.configure(attesters, 1);

		for (uint256 i; i < length; ++i) {
			vm.expectRevert(abi.encodeWithSelector(AttesterAlreadyExists.selector, attesters[i]));
			aux.registryFactory.authorize(attesters[i]);
		}
	}

	function test_addAttester_revertsWithExceededMaxAttesters() public virtual impersonate(ADMIN, false) {
		uint256 threshold = 32;
		address[] memory attesters = prepareAttesters(threshold, false);

		aux.registryFactory.configure(attesters[0].addresses(), 1);

		for (uint256 i = 1; i < threshold; ++i) {
			aux.registryFactory.authorize(attesters[i]);
			assertTrue(aux.registryFactory.isAuthorized(attesters[i]));
		}

		attesters.insertionSort();
		attesters.uniquifySorted();
		assertEq(attesters, aux.registryFactory.getTrustedAttesters());

		vm.expectRevert(ExceededMaxAttesters.selector);
		aux.registryFactory.authorize(vm.addr(key + threshold));
	}

	function test_removeAttester() public virtual impersonate(ADMIN, false) {
		uint256 length = 5;
		address[] memory attesters = prepareAttesters(length, true);

		aux.registryFactory.configure(attesters, 1);
		assertEq(attesters, aux.registryFactory.getTrustedAttesters());

		for (uint256 i = 1; i < length; ++i) {
			aux.registryFactory.revoke(attesters[i]);
			assertFalse(aux.registryFactory.isAuthorized(attesters[i]));
		}

		assertEq(attesters[0].addresses(), aux.registryFactory.getTrustedAttesters());
	}

	function test_removeAttester_revertsWithUnauthorized() public virtual {
		address[] memory attesters = prepareAttesters(3, true);

		vm.prank(ADMIN.eoa);
		aux.registryFactory.configure(attesters, 1);

		for (uint256 i; i < attesters.length; ++i) {
			vm.expectRevert(Unauthorized.selector);
			aux.registryFactory.revoke(attesters[i]);
		}
	}

	function test_removeAttester_revertsWithAttesterNotExists() public virtual impersonate(ADMIN, false) {
		address[] memory attesters = prepareAttesters(2, true);

		aux.registryFactory.configure(attesters, 1);
		assertEq(attesters, aux.registryFactory.getTrustedAttesters());

		vm.expectRevert(abi.encodeWithSelector(AttesterNotExists.selector, ALICE.eoa));
		aux.registryFactory.revoke(ALICE.eoa);

		vm.expectRevert(abi.encodeWithSelector(AttesterNotExists.selector, COOPER.eoa));
		aux.registryFactory.revoke(COOPER.eoa);

		vm.expectRevert(abi.encodeWithSelector(AttesterNotExists.selector, MURPHY.eoa));
		aux.registryFactory.revoke(MURPHY.eoa);
	}

	function test_removeAttester_revertsWithInvalidAttesters() public virtual impersonate(ADMIN, false) {
		aux.registryFactory.configure(prepareAttesters(2, true), 1);

		vm.expectRevert(InvalidAttester.selector);
		aux.registryFactory.revoke(address(0));
	}

	function test_removeAttester_reverts() internal virtual impersonate(ADMIN, false) {
		//
	}

	// function test_() public virtual {}

	function test_createAccount() internal virtual {}

	function test_createAccountViaMetaFactory() internal virtual {}

	function prepareAttesters(uint256 length, bool flag) internal view virtual returns (address[] memory attesters) {
		attesters = new address[](length);

		for (uint256 i; i < length; ++i) {
			attesters[i] = vm.addr(key + i);
		}

		if (flag) {
			attesters.insertionSort();
			attesters.uniquifySorted();
		}
	}
}
