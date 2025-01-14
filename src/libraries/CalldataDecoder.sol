// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";

/// @title CalldataDecoder

library CalldataDecoder {
	uint256 internal constant LENGTH_MASK = 0xffffffff;
	uint256 internal constant LENGTH_MASK_AND_WORD_ALIGN = 0xffffffe0;

	function decodeSelector(bytes calldata data) internal pure returns (bytes4 selector) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			selector := calldataload(data.offset)
			if iszero(selector) {
				mstore(0x00, 0x7352d91c) // InvalidSelector()
				revert(0x1c, 0x04)
			}
		}
	}

	function decodeSelectors(bytes calldata data, uint256 index) internal pure returns (bytes4[] calldata selectors) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			selectors.length := length
			selectors.offset := offset
		}
	}

	function decodeCurrency(bytes calldata data) internal pure returns (Currency value) {
		assembly ("memory-safe") {
			if lt(data.length, 0x20) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(data.offset)
		}
	}

	function decodeCurrency(bytes calldata data, uint256 index) internal pure returns (Currency value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function decodeAddress(bytes calldata data) internal pure returns (address value) {
		assembly ("memory-safe") {
			if lt(data.length, 0x14) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := shr(0x60, calldataload(data.offset))
		}
	}

	function decodeAddress(bytes calldata data, uint256 index) internal pure returns (address value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function decodeBytes32(bytes calldata data, uint256 index) internal pure returns (bytes32 value) {
		assembly ("memory-safe") {
			if lt(data.length, shl(0x05, add(index, 0x01))) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(add(data.offset, shl(0x05, index)))
		}
	}

	function decodeUint256(bytes calldata data) internal pure returns (uint256 value) {
		assembly ("memory-safe") {
			if lt(data.length, 0x20) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			value := calldataload(data.offset)
		}
	}

	function decodeBytes(bytes calldata data, uint256 index) internal pure returns (bytes calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toLengthOffset(bytes calldata data, uint256 index) internal pure returns (uint256 length, uint256 offset) {
		assembly ("memory-safe") {
			let lengthPtr := add(data.offset, and(calldataload(add(data.offset, shl(0x05, index))), LENGTH_MASK))
			length := and(calldataload(lengthPtr), LENGTH_MASK)
			offset := add(lengthPtr, 0x20)

			if lt(add(data.length, data.offset), add(length, offset)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}
		}
	}
}
