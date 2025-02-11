// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Calldata
/// @notice Library for manipulating objects in calldata

library Calldata {
	function hash(bytes calldata data) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			calldatacopy(ptr, data.offset, data.length)
			digest := keccak256(ptr, data.length)
		}
	}

	function emptyBytes() internal pure returns (bytes calldata result) {
		assembly ("memory-safe") {
			result.offset := 0x00
			result.length := 0x00
		}
	}

	function emptyString() internal pure returns (string calldata result) {
		assembly ("memory-safe") {
			result.offset := 0x00
			result.length := 0x00
		}
	}
}
