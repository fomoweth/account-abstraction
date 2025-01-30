// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {Arrays} from "src/libraries/Arrays.sol";

abstract contract Signers is CommonBase {
	using Arrays for address[];

	struct Signer {
		address payable addr;
		uint256 publicKeyX;
		uint256 publicKeyY;
		uint256 privateKey;
	}

	Signer internal DEPLOYER;
	Signer internal BUNDLER;
	Signer internal ALICE;
	Signer internal BOB;
	Signer internal COOPER;

	address payable internal DEPLOYER_ADDRESS;
	address payable internal BUNDLER_ADDRESS;
	address payable internal ALICE_ADDRESS;
	address payable internal BOB_ADDRESS;
	address payable internal COOPER_ADDRESS;

	address[] internal ATTESTER_ADDRESSES;
	uint256 internal ATTESTERS_COUNT = 2;
	uint8 internal THRESHOLD = 1;

	address[] internal SENDER_ADDRESSES;
	uint256 internal SENDERS_COUNT = 3;

	uint256 internal constant INITIAL_VALUE = 1000 ether;

	modifier impersonate(address signer) {
		vm.startPrank(signer);
		_;
		vm.stopPrank();
	}

	function setUpSigners() internal virtual {
		DEPLOYER = createSigner("DEPLOYER", INITIAL_VALUE);
		DEPLOYER_ADDRESS = DEPLOYER.addr;

		BUNDLER = createSigner("BUNDLER", INITIAL_VALUE);
		BUNDLER_ADDRESS = BUNDLER.addr;

		ALICE = createSigner("ALICE", INITIAL_VALUE);
		ALICE_ADDRESS = ALICE.addr;

		BOB = createSigner("BOB", INITIAL_VALUE);
		BOB_ADDRESS = BOB.addr;

		COOPER = createSigner("COOPER", INITIAL_VALUE);
		COOPER_ADDRESS = COOPER.addr;

		ATTESTER_ADDRESSES = createSignerAddresses("ATTESTER", ATTESTERS_COUNT, true, INITIAL_VALUE);

		SENDER_ADDRESSES = createSignerAddresses("SENDER", SENDERS_COUNT, true, INITIAL_VALUE);
	}

	function createSigner(string memory name, uint256 value) internal virtual returns (Signer memory s) {
		(s.publicKeyX, s.publicKeyY) = vm.publicKeyP256((s.privateKey = encodePrivateKey(name)));
		vm.label((s.addr = payable(vm.addr(s.privateKey))), name);
		vm.deal(s.addr, value);
	}

	function createSignerAddresses(
		string memory prefix,
		uint256 count,
		bool shouldSort,
		uint256 value
	) internal virtual returns (address[] memory addresses) {
		addresses = new address[](count);
		for (uint256 i; i < count; ++i) {
			string memory name = string.concat(prefix, " #", vm.toString(i));
			vm.label((addresses[i] = vm.addr(encodePrivateKey(name))), name);
			vm.deal(addresses[i], value);
		}

		if (shouldSort) {
			addresses.sort();
			addresses.uniquifySorted();
		}
	}

	function encodePrivateKey(string memory key) internal pure virtual returns (uint256) {
		return uint256(keccak256(abi.encodePacked(key)));
	}
}
