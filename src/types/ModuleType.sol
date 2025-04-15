// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
	MODULE_TYPE_VALIDATOR,
	MODULE_TYPE_EXECUTOR,
	MODULE_TYPE_FALLBACK,
	MODULE_TYPE_HOOK,
	MODULE_TYPE_POLICY,
	MODULE_TYPE_SIGNER,
	MODULE_TYPE_STATELESS_VALIDATOR
} from "./Constants.sol";

type ModuleType is uint256;

type PackedModuleTypes is uint32;

using ModuleTypeLib for ModuleType global;
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
	error InvalidModuleType();

	function isType(PackedModuleTypes packedTypes, ModuleType moduleType) internal pure returns (bool result) {
		assembly ("memory-safe") {
			result := and(packedTypes, shl(moduleType, 0x01))
		}
	}

	function numberOfTypes(PackedModuleTypes packedTypes) internal pure returns (uint256 count) {
		assembly ("memory-safe") {
			for { let moduleType } lt(moduleType, 0x20) { moduleType := add(moduleType, 0x01) } {
				if and(packedTypes, shl(moduleType, 0x01)) {
					count := add(count, 0x01)
				}
			}
		}
	}

	function decode(PackedModuleTypes packedTypes) internal pure returns (ModuleType[] memory moduleTypes) {
		assembly ("memory-safe") {
			moduleTypes := mload(0x40)

			let offset := add(moduleTypes, 0x20)
			let length

			for { let moduleType } lt(moduleType, 0x20) { moduleType := add(moduleType, 0x01) } {
				if and(packedTypes, shl(moduleType, 0x01)) {
					mstore(add(offset, shl(0x05, length)), moduleType)
					length := add(length, 0x01)
				}
			}

			mstore(moduleTypes, length)
			mstore(0x40, add(moduleTypes, shl(0x05, add(length, 0x01))))
		}
	}

	function encode(ModuleType[] memory moduleTypes) internal pure returns (PackedModuleTypes packedTypes) {
		assembly ("memory-safe") {
			let offset := add(moduleTypes, 0x20)
			let guard := add(offset, shl(0x05, mload(moduleTypes)))

			for { } 0x01 { } {
				let moduleType := mload(offset)

				if or(gt(moduleType, 0x1f), and(packedTypes, shl(moduleType, 0x01))) {
					mstore(0x00, 0x2125deae) // InvalidModuleType()
					revert(0x1c, 0x04)
				}

				packedTypes := or(packedTypes, shl(moduleType, 0x01))
				offset := add(offset, 0x20)

				if iszero(lt(offset, guard)) { break }
			}
		}
	}

	function arrayify(ModuleType moduleTypeId) internal pure returns (ModuleType[] memory moduleTypeIds) {
		moduleTypeIds = new ModuleType[](1);
		moduleTypeIds[0] = moduleTypeId;
	}
}
