// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType} from "src/types/ExecutionMode.sol";
import {BytesLib} from "./BytesLib.sol";

/// @title CalldataDecoder

library CalldataDecoder {
	using BytesLib for bytes;

	function decodeSelector(bytes calldata data) internal pure returns (bytes4 selector) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			selector := calldataload(data.offset)
		}
	}

	function decodeSelectors(bytes calldata data, uint256 index) internal pure returns (bytes4[] calldata selectors) {
		(uint256 length, uint256 offset) = data.toLengthOffset(index);

		assembly ("memory-safe") {
			selectors.length := length
			selectors.offset := offset
		}
	}

	function decodeSelectorAndCalldata(
		bytes calldata data
	) internal pure returns (bytes4 selector, bytes calldata callData) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			selector := calldataload(data.offset)
			callData.offset := add(data.offset, 0x04)
			callData.length := sub(data.length, 0x04)
		}
	}

	function decodeSelectorsAndCallTypes(
		bytes calldata data
	) internal pure returns (bytes4[] calldata selectors, CallType[] calldata callTypes) {
		assembly ("memory-safe") {
			let offset := data.offset
			let ptr := add(offset, calldataload(offset))

			selectors.length := calldataload(ptr)
			selectors.offset := add(ptr, 0x20)
			offset := add(offset, 0x20)

			ptr := add(data.offset, calldataload(offset))
			callTypes.length := calldataload(ptr)
			callTypes.offset := add(ptr, 0x20)
		}
	}

	function decodeEnableMode(
		bytes calldata data
	)
		internal
		pure
		returns (
			address module,
			uint256 moduleTypeId,
			bytes calldata initData,
			bytes calldata signature,
			bytes calldata userOpSignature
		)
	{
		assembly ("memory-safe") {
			let offset := data.offset
			let baseOffset := offset

			module := shr(0x60, calldataload(offset))
			offset := add(offset, 0x14)

			moduleTypeId := calldataload(offset)
			offset := add(offset, 0x20)

			initData.length := shr(0xe0, calldataload(add(offset, 0x20)))
			initData.offset := add(offset, 0x24)
			offset := add(initData.offset, initData.length)

			signature.length := shr(0xe0, calldataload(offset))
			signature.offset := add(offset, 0x04)
			offset := sub(add(signature.offset, signature.length), data.offset)

			userOpSignature.offset := add(data.offset, offset)
			userOpSignature.length := sub(data.length, offset)
		}
	}
}
