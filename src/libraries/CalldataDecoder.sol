// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode, CallType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";

/// @title CalldataDecoder
/// @notice Library for abi decoding in calldata.
library CalldataDecoder {
	function decodeSelector(bytes calldata params) internal pure returns (bytes4 selector) {
		assembly ("memory-safe") {
			if lt(params.length, 0x04) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			selector := calldataload(params.offset)
		}
	}

	function decodeExecutionCalldata(
		bytes calldata params
	) internal pure returns (ExecutionMode mode, bytes calldata executionCalldata) {
		assembly ("memory-safe") {
			if lt(params.length, 0x20) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			mode := calldataload(params.offset)

			let ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			executionCalldata.offset := add(ptr, 0x20)
			executionCalldata.length := calldataload(ptr)
		}
	}

	function decodeInstallModuleParams(
		bytes calldata params
	)
		internal
		pure
		returns (PackedModuleTypes packedTypes, bytes calldata moduleData, address hook, bytes calldata hookData)
	{
		assembly ("memory-safe") {
			let ptr := params.offset
			packedTypes := shr(0xe0, calldataload(ptr))

			ptr := add(ptr, 0x04)
			moduleData.offset := add(ptr, 0x04)
			moduleData.length := shr(0xe0, calldataload(ptr))

			ptr := add(moduleData.offset, moduleData.length)
			hookData.offset := add(ptr, 0x04)
			hookData.length := shr(0xe0, calldataload(ptr))

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
		bytes calldata params
	) internal pure returns (bytes calldata moduleData, bytes calldata hookData) {
		assembly ("memory-safe") {
			let ptr := params.offset
			moduleData.offset := add(ptr, 0x04)
			moduleData.length := shr(0xe0, calldataload(ptr))

			ptr := add(moduleData.offset, moduleData.length)
			hookData.offset := add(ptr, 0x04)
			hookData.length := shr(0xe0, calldataload(ptr))
		}
	}

	function decodeFallbackParams(
		bytes calldata params
	) internal pure returns (bytes32[] calldata selectors, bytes1 flag, bytes calldata moduleData) {
		assembly ("memory-safe") {
			let ptr := add(params.offset, calldataload(params.offset))
			selectors.offset := add(ptr, 0x20)
			selectors.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			moduleData.offset := add(ptr, 0x20)
			moduleData.length := calldataload(ptr)

			if moduleData.length {
				flag := calldataload(moduleData.offset)
				moduleData.offset := add(moduleData.offset, 0x01)
				moduleData.length := sub(moduleData.length, 0x01)
			}
		}
	}

	function decodeEnableModuleParams(
		bytes calldata params
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
			let ptr := params.offset
			moduleTypeId := shr(0xf8, calldataload(ptr))

			ptr := add(ptr, 0x01)
			module := shr(0x60, calldataload(ptr))

			ptr := add(ptr, 0x14)
			initData.offset := add(ptr, 0x04)
			initData.length := shr(0xe0, calldataload(ptr))

			ptr := add(initData.offset, initData.length)
			signature.offset := add(ptr, 0x04)
			signature.length := shr(0xe0, calldataload(ptr))

			ptr := sub(add(signature.offset, signature.length), params.offset)
			userOpSignature.offset := add(params.offset, ptr)
			userOpSignature.length := sub(params.length, ptr)
		}
	}
}
