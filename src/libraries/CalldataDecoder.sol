// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode, CallType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";
import {BytesLib} from "./BytesLib.sol";

/// @title CalldataDecoder

library CalldataDecoder {
	using BytesLib for bytes;

	function decodeSelector(bytes calldata data) internal pure returns (bytes4 selector) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			selector := calldataload(data.offset)
		}
	}

	function decodeUserOpCalldata(
		bytes calldata data
	) internal pure returns (ExecutionMode mode, bytes calldata executionCalldata) {
		assembly ("memory-safe") {
			let selector := shr(0xe0, calldataload(data.offset))

			// execute(bytes32,bytes) | executeFromExecutor(bytes32,bytes)
			if and(xor(selector, 0xe9ae5c53), xor(selector, 0xd691c964)) {
				mstore(0x00, 0x7352d91c) // InvalidSelector()
				revert(0x1c, 0x04)
			}

			mode := calldataload(add(data.offset, 0x04))

			let ptr := add(data.offset, calldataload(add(data.offset, 0x24)))
			executionCalldata.length := calldataload(ptr)
			executionCalldata.offset := add(ptr, 0x20)
		}
	}

	function decodeInstallModuleData(
		bytes calldata data
	)
		internal
		pure
		returns (PackedModuleTypes packedTypes, bytes calldata installData, address hook, bytes calldata hookData)
	{
		assembly ("memory-safe") {
			let ptr := data.offset
			packedTypes := shr(0xe0, calldataload(ptr))

			ptr := add(ptr, 0x04)
			installData.length := shr(0xe0, calldataload(ptr))
			installData.offset := add(ptr, 0x04)

			ptr := add(installData.offset, installData.length)
			hookData.length := shr(0xe0, calldataload(ptr))
			hookData.offset := add(ptr, 0x04)

			if iszero(lt(hookData.length, 0x14)) {
				hook := shr(0x60, calldataload(hookData.offset))
				hookData.offset := add(hookData.offset, 0x14)
				hookData.length := sub(hookData.length, 0x14)
			}

			if iszero(hook) {
				hook := 0x01
			}
		}
	}

	function decodeUninstallModuleData(
		bytes calldata data
	) internal pure returns (bytes calldata uninstallData, bytes calldata hookData) {
		assembly ("memory-safe") {
			let ptr := data.offset
			uninstallData.length := shr(0xe0, calldataload(ptr))
			uninstallData.offset := add(ptr, 0x04)

			ptr := add(uninstallData.offset, uninstallData.length)
			hookData.length := shr(0xe0, calldataload(ptr))
			hookData.offset := add(ptr, 0x04)
		}
	}

	function decodeFallbackData(
		bytes calldata data
	) internal pure returns (bytes32[] calldata selectors, bytes1 flag, bytes calldata installData) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, calldataload(data.offset))
			selectors.length := calldataload(ptr)
			selectors.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			installData.length := calldataload(ptr)
			installData.offset := add(ptr, 0x20)

			if installData.length {
				flag := calldataload(installData.offset)
				installData.offset := add(installData.offset, 0x01)
				installData.length := sub(installData.length, 0x01)
			}
		}
	}

	function decodeEnableModuleData(
		bytes calldata data
	)
		internal
		pure
		returns (
			address module,
			ModuleType moduleTypeId,
			bytes calldata installData,
			bytes calldata signature,
			bytes calldata userOpSignature
		)
	{
		assembly ("memory-safe") {
			let ptr := data.offset
			module := shr(0x60, calldataload(ptr))

			ptr := add(ptr, 0x14)
			moduleTypeId := calldataload(ptr)

			ptr := add(ptr, 0x20)
			installData.length := shr(0xe0, calldataload(ptr))
			installData.offset := add(ptr, 0x04)

			ptr := add(installData.offset, installData.length)
			signature.length := shr(0xe0, calldataload(ptr))
			signature.offset := add(ptr, 0x04)

			ptr := sub(add(signature.offset, signature.length), data.offset)
			userOpSignature.offset := add(data.offset, ptr)
			userOpSignature.length := sub(data.length, ptr)
		}
	}
}
