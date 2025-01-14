// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type ModuleType is uint256;

type PackedModuleTypes is uint32;

using ModuleTypeLib for PackedModuleTypes global;
using { eqModuleType as ==, neqModuleType as !=  } for ModuleType global;
using { eqPackedModuleTypes as ==, neqPackedModuleTypes as !=  } for PackedModuleTypes global;

function eqModuleType(ModuleType x, ModuleType y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := eq(x, y)
	}
}

function neqModuleType(ModuleType x, ModuleType y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := xor(x, y)
	}
}

function eqPackedModuleTypes(PackedModuleTypes x, PackedModuleTypes y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := eq(x, y)
	}
}

function neqPackedModuleTypes(PackedModuleTypes x, PackedModuleTypes y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := xor(x, y)
	}
}

/// @title ModuleTypeLib
/// @notice Provides functions for handling module type and packed module types

library ModuleTypeLib {
	function isType(PackedModuleTypes packedTypes, ModuleType moduleType) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(packedTypes, shl(moduleType, 0x01))
		}
	}

	function pack(ModuleType[] memory moduleTypes) internal pure returns (PackedModuleTypes packedTypes) {
		// prettier-ignore
		assembly ("memory-safe") {
			let offset := add(moduleTypes, 0x20)
			let guard := add(offset, shl(0x05, mload(moduleTypes)))

			for { } 0x01 { } {
				packedTypes := or(packedTypes, shl(mload(offset), 0x01))
				offset := add(offset, 0x20)

				if iszero(lt(offset, guard)) { break }
			}
		}
	}
}
