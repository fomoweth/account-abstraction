// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK, MODULE_TYPE_POLICY, MODULE_TYPE_SIGNER, MODULE_TYPE_STATELESS_VALIDATOR} from "./Constants.sol";

type ModuleType is uint256;

type PackedModuleTypes is uint32;

using ModuleTypeLib for PackedModuleTypes global;
using { eqModuleType as ==, neqModuleType as !=  } for ModuleType global;
using { eqPackedModuleTypes as ==, neqPackedModuleTypes as !=  } for PackedModuleTypes global;

function eqModuleType(ModuleType x, ModuleType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqModuleType(ModuleType x, ModuleType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqPackedModuleTypes(PackedModuleTypes x, PackedModuleTypes y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqPackedModuleTypes(PackedModuleTypes x, PackedModuleTypes y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title ModuleTypeLib
/// @notice Provides functions for handling module type and packed module types

library ModuleTypeLib {
	function isType(PackedModuleTypes packedTypes, ModuleType moduleType) internal pure returns (bool res) {
		assembly ("memory-safe") {
			res := and(packedTypes, shl(moduleType, 0x01))
		}
	}

	function numberOfTypes(PackedModuleTypes packedTypes) internal pure returns (uint256 count) {
		assembly ("memory-safe") {
			// prettier-ignore
			for { let i } lt(i, 0x20) { i := add(i, 0x01) } {
				if and(packedTypes, shl(i, 0x01)) {
					count := add(count, 0x01)
				}
			}
		}
	}

	function decode(PackedModuleTypes packedTypes) internal pure returns (ModuleType[] memory moduleTypes) {
		// prettier-ignore
		assembly ("memory-safe") {
			moduleTypes := mload(0x40)
			mstore(moduleTypes, 0x07)

			let ptr := add(moduleTypes, 0x20)
			let offset

			for { let i } lt(i, 0x20) { i := add(i, 0x01) } {
				if and(packedTypes, shl(i, 0x01)) {
					mstore(add(ptr, mul(offset, 0x20)), i)
					offset := add(offset, 0x01)
				}
			}

			mstore(moduleTypes, offset)
			mstore(0x40, add(moduleTypes, mul(add(offset, 0x01), 0x20)))
		}
	}

	function encode(ModuleType[] memory moduleTypes) internal pure returns (PackedModuleTypes packedTypes) {
		assembly ("memory-safe") {
			let offset := add(moduleTypes, 0x20)
			let guard := add(offset, shl(0x05, mload(moduleTypes)))

			// prettier-ignore
			for { } 0x01 { } {
				let moduleType := mload(offset)
				if or(gt(moduleType, 0x1f), and(packedTypes, shl(moduleType, 0x01))) {
					mstore(0x00, 0x098312d2) // InvalidModuleTypeId(uint256)
					mstore(0x20, moduleType)
					revert(0x1c, 0x24)
				}

				packedTypes := or(packedTypes, shl(moduleType, 0x01))
				offset := add(offset, 0x20)
				if iszero(lt(offset, guard)) { break }
			}
		}
	}
}
