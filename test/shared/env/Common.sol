// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdMath} from "forge-std/StdMath.sol";

import {Currency} from "src/types/Currency.sol";
import {Constants} from "./Constants.sol";

abstract contract Common is Constants {
	function emptyBytes() internal pure virtual returns (bytes calldata data) {
		assembly ("memory-safe") {
			data.offset := 0x00
			data.length := 0x00
		}
	}

	function emptyString() internal pure virtual returns (string calldata str) {
		assembly ("memory-safe") {
			str.offset := 0x00
			str.length := 0x00
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

	function bytes32ToAddress(bytes32 input) internal pure virtual returns (address output) {
		return address(uint160(uint256(input)));
	}

	function addressToBytes32(address input) internal pure virtual returns (bytes32 output) {
		return bytes32(bytes20(input));
	}

	function isContract(address target) internal view virtual returns (bool res) {
		assembly ("memory-safe") {
			res := iszero(iszero(extcodesize(target)))
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
}
