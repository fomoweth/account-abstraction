// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode, CallType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";

/// @title CalldataDecoder

library CalldataDecoder {
	function decodeSelector(bytes calldata data) internal pure returns (bytes4 selector) {
		assembly ("memory-safe") {
			if lt(data.length, 0x04) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			selector := calldataload(data.offset)
		}
	}

	function decodeExecutionModeAndCalldata(
		bytes calldata data
	) internal pure returns (ExecutionMode mode, bytes calldata executionCalldata) {
		assembly ("memory-safe") {
			mode := calldataload(data.offset)

			let ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			executionCalldata.length := calldataload(ptr)
			executionCalldata.offset := add(ptr, 0x20)
		}
	}

	function decodeInstallModuleParams(
		bytes calldata data
	)
		internal
		pure
		returns (PackedModuleTypes packedTypes, bytes calldata moduleData, address hook, bytes calldata hookData)
	{
		assembly ("memory-safe") {
			let ptr := data.offset
			packedTypes := shr(0xe0, calldataload(ptr))

			ptr := add(ptr, 0x04)
			moduleData.length := shr(0xe0, calldataload(ptr))
			moduleData.offset := add(ptr, 0x04)

			ptr := add(moduleData.offset, moduleData.length)
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

	function decodeUninstallModuleParams(
		bytes calldata data
	) internal pure returns (bytes calldata moduleData, bytes calldata hookData) {
		assembly ("memory-safe") {
			let ptr := data.offset
			moduleData.length := shr(0xe0, calldataload(ptr))
			moduleData.offset := add(ptr, 0x04)

			ptr := add(moduleData.offset, moduleData.length)
			hookData.length := shr(0xe0, calldataload(ptr))
			hookData.offset := add(ptr, 0x04)
		}
	}

	function decodeFallbackParams(
		bytes calldata data
	) internal pure returns (bytes32[] calldata selectors, bytes1 flag, bytes calldata moduleData) {
		assembly ("memory-safe") {
			let ptr := add(data.offset, calldataload(data.offset))
			selectors.length := calldataload(ptr)
			selectors.offset := add(ptr, 0x20)

			ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			moduleData.length := calldataload(ptr)
			moduleData.offset := add(ptr, 0x20)

			if moduleData.length {
				flag := calldataload(moduleData.offset)
				moduleData.offset := add(moduleData.offset, 0x01)
				moduleData.length := sub(moduleData.length, 0x01)
			}
		}
	}

	function decodeEnableModuleParams(
		bytes calldata data
	)
		internal
		pure
		returns (
			ModuleType moduleTypeId,
			address module,
			bytes calldata initData,
			bytes calldata signature,
			bytes calldata userOpSignature
		)
	{
		assembly ("memory-safe") {
			let ptr := data.offset

			moduleTypeId := shr(0xf8, calldataload(ptr))
			ptr := add(ptr, 0x01)

			module := shr(0x60, calldataload(ptr))
			ptr := add(ptr, 0x14)

			initData.length := shr(0xe0, calldataload(ptr))
			initData.offset := add(ptr, 0x04)
			ptr := add(initData.offset, initData.length)

			signature.length := shr(0xe0, calldataload(ptr))
			signature.offset := add(ptr, 0x04)
			ptr := sub(add(signature.offset, signature.length), data.offset)

			userOpSignature.offset := add(data.offset, ptr)
			userOpSignature.length := sub(data.length, ptr)
		}
	}
}
