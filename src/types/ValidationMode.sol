// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type ValidationMode is bytes1;

using ValidationModeLib for ValidationMode global;
using {eqValidationMode as ==, neqValidationMode as !=} for ValidationMode global;

function eqValidationMode(ValidationMode x, ValidationMode y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqValidationMode(ValidationMode x, ValidationMode y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title ValidationModeLib

library ValidationModeLib {
	// [1 bytes validation mode][3 bytes unused][20 bytes validator][8 bytes nonce]
	function encodeNonceKey(ValidationMode mode, address validator) internal pure returns (uint192 key) {
		assembly ("memory-safe") {
			key := or(shr(0x40, mode), validator)
		}
	}
}