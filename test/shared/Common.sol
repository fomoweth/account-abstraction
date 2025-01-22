// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {stdMath} from "forge-std/StdMath.sol";

import {Currency} from "src/types/Currency.sol";

import {Constants} from "./Constants.sol";

abstract contract Common is CommonBase, Constants {
	uint256 internal constant DEFAULT_MAX_PERCENT_DELTA = 1e11;

	uint256 internal snapshotId = MAX_UINT256;

	function revertToState() internal virtual {
		if (snapshotId != MAX_UINT256) vm.revertToState(snapshotId);
		snapshotId = vm.snapshotState();
	}

	function emptyAddresses() internal pure virtual returns (address[] memory) {
		return new address[](0);
	}

	function emptyBytes() internal pure virtual returns (bytes calldata data) {
		assembly ("memory-safe") {
			data.offset := 0x00
			data.length := 0x00
		}
	}

	function calldataKeccak256(bytes calldata data) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			calldatacopy(ptr, data.offset, data.length)
			digest := keccak256(ptr, data.length)
		}
	}

	function memoryKeccak256(bytes memory data) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			digest := keccak256(add(data, 0x20), mload(data))
		}
	}

	function bytes32ToAddress(bytes32 input) internal pure returns (address output) {
		return address(uint160(uint256(input)));
	}

	function addressToBytes32(address input) internal pure returns (bytes32 output) {
		return bytes32(bytes20(input));
	}

	function arrayify(address input) internal pure virtual returns (address[] memory output) {
		output = new address[](1);
		output[0] = input;
	}

	function arrayify(bytes32 input) internal pure virtual returns (bytes32[] memory output) {
		output = new bytes32[](1);
		output[0] = input;
	}

	function arrayify(uint256 input) internal pure virtual returns (uint256[] memory output) {
		output = new uint256[](1);
		output[0] = input;
	}

	function isContract(address target) internal view virtual returns (bool flag) {
		assembly ("memory-safe") {
			flag := iszero(iszero(extcodesize(target)))
		}
	}

	function assertContract(address target) internal virtual {
		vm.assertTrue(isContract(target));
	}

	function assertNotZero(address target) internal virtual {
		vm.assertTrue(target != address(0));
	}

	function assertNotZero(Currency target) internal virtual {
		assertNotZero(target.toAddress());
	}

	function assertEq(Currency x, Currency y) internal virtual {
		vm.assertEq(x.toAddress(), y.toAddress());
	}

	function assertCloseTo(uint256 x, uint256 y) internal virtual {
		assertCloseTo(x, y, DEFAULT_MAX_PERCENT_DELTA);
	}

	function assertCloseTo(uint256 x, uint256 y, uint256 maxPercentDelta) internal virtual {
		if (y == 0) return vm.assertEq(x, y);

		uint256 percentDelta = stdMath.percentDelta(x, y);
		vm.assertLe(percentDelta, maxPercentDelta);
	}
}
