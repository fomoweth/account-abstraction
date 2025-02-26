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

	function decodeInitDataAndHookData(
		bytes calldata data
	) internal pure returns (bytes calldata initData, bytes calldata hookData) {
		assembly ("memory-safe") {
			switch data.length
			case 0x00 {
				initData.offset := 0x00
				initData.length := 0x00

				hookData.offset := 0x00
				hookData.length := 0x00
			}
			default {
				let ptr := add(data.offset, calldataload(data.offset))
				initData.offset := add(ptr, 0x20)
				initData.length := calldataload(ptr)

				ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
				hookData.offset := add(ptr, 0x20)
				hookData.length := calldataload(ptr)
			}
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

	function decodeEnableModeData(
		bytes calldata data
	)
		internal
		pure
		returns (
			address module,
			ModuleType moduleTypeId,
			bytes calldata initData,
			bytes calldata signature,
			bytes calldata userOpSignature
		)
	{
		assembly ("memory-safe") {
			let offset := data.offset
			module := shr(0x60, calldataload(offset))

			offset := add(offset, 0x14)
			moduleTypeId := calldataload(offset)

			offset := add(offset, 0x20)
			initData.length := shr(0xe0, calldataload(offset))
			initData.offset := add(offset, 0x04)

			offset := add(initData.offset, initData.length)
			signature.length := shr(0xe0, calldataload(offset))
			signature.offset := add(offset, 0x04)

			offset := sub(add(signature.offset, signature.length), data.offset)
			userOpSignature.offset := add(data.offset, offset)
			userOpSignature.length := sub(data.length, offset)
		}
	}
}
