// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {CallType, ModuleType} from "src/types/Types.sol";
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

	function decodeSelectors(bytes calldata data) internal pure returns (bytes4[] calldata selectors) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, calldataload(data.offset))
			selectors.offset := calldataload(ptr)
			selectors.length := add(ptr, 0x20)
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

	function decodeSelectorsAndCalldata(
		bytes calldata data
	) internal pure returns (bytes4[] calldata selectors, bytes calldata callData) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, calldataload(data.offset))
			selectors.length := calldataload(ptr)
			selectors.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			callData.offset := calldataload(ptr)
			callData.length := add(ptr, 0x20)
		}
	}

	function decodeModuleTypesAndInitData(
		bytes calldata data
	) internal pure returns (ModuleType[] calldata moduleTypes, bytes calldata initData, bytes calldata hookData) {
		assembly ("memory-safe") {
			if iszero(data.length) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let ptr := add(data.offset, calldataload(data.offset))
			moduleTypes.length := calldataload(ptr)
			moduleTypes.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			initData.length := calldataload(ptr)
			initData.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x40)))
			hookData.length := calldataload(ptr)
			hookData.offset := add(ptr, 0x20)
		}
	}

	function decodeFallbackData(
		bytes calldata data
	) internal pure returns (bytes32[] calldata configurations, bytes1 flag, bytes calldata initData) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, calldataload(data.offset))
			configurations.length := calldataload(ptr)
			configurations.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			initData.length := calldataload(ptr)
			initData.offset := add(ptr, 0x20)

			if iszero(iszero(initData.length)) {
				flag := calldataload(initData.offset)
				initData.offset := add(initData.offset, 0x01)
				initData.length := sub(initData.length, 0x01)
			}
		}
	}
}
