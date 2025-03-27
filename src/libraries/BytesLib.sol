// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";

/// @title BytesLib
/// @dev Modified from https://github.com/Uniswap/universal-router/blob/main/contracts/modules/uniswap/v3/BytesLib.sol

library BytesLib {
	uint256 internal constant LENGTH_MASK = 0xffffffff;

	function toAddress(bytes calldata data) internal pure returns (address value) {
		assembly ("memory-safe") {
			if lt(data.length, 0x14) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := shr(0x60, calldataload(data.offset))
		}
	}

	function toAddress(bytes calldata data, uint256 index) internal pure returns (address value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function toAddressArray(bytes calldata data, uint256 index) internal pure returns (address[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toCurrency(bytes calldata data) internal pure returns (Currency value) {
		assembly ("memory-safe") {
			if lt(data.length, 0x14) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := shr(0x60, calldataload(data.offset))
		}
	}

	function toCurrency(bytes calldata data, uint256 index) internal pure returns (Currency value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function toCurrencyArray(bytes calldata data, uint256 index) internal pure returns (Currency[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toBytes32(bytes calldata data, uint256 index) internal pure returns (bytes32 value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function toBytes32Array(bytes calldata data, uint256 index) internal pure returns (bytes32[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toUint256(bytes calldata data, uint256 index) internal pure returns (uint256 value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function toUint256Array(bytes calldata data, uint256 index) internal pure returns (uint256[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toBytes(bytes calldata data, uint256 index) internal pure returns (bytes calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toBytesArray(bytes calldata data, uint256 index) internal pure returns (bytes[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toLengthOffset(bytes calldata data, uint256 index) internal pure returns (uint256 length, uint256 offset) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, and(calldataload(add(data.offset, shl(0x05, index))), LENGTH_MASK))
			length := and(calldataload(ptr), LENGTH_MASK)
			offset := add(ptr, 0x20)

			if lt(add(data.length, data.offset), add(length, offset)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}
		}
	}
}
