// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "./Constants.sol";

type ValidationData is uint256;

using ValidationDataLib for ValidationData global;

using {eqValidationData as ==, neqValidationData as !=} for ValidationData global;

function eqValidationData(ValidationData x, ValidationData y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqValidationData(ValidationData x, ValidationData y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title ValidationDataLib
/// @notice Provides functions for encoding and decoding validations

library ValidationDataLib {
	uint48 internal constant MAX_UINT48 = (1 << 48) - 1;

	function encode(
		bool flag,
		uint48 validUntil,
		uint48 validAfter
	) internal pure returns (ValidationData validationData) {
		assembly ("memory-safe") {
			validationData := or(add(shl(208, validAfter), shl(160, validUntil)), and(iszero(iszero(flag)), 0xff))
		}
	}

	function decode(
		ValidationData validationData
	) internal pure returns (bool failed, uint48 validUntil, uint48 validAfter) {
		assembly ("memory-safe") {
			failed := and(validationData, 0x01)
			validUntil := and(shr(160, validationData), MAX_UINT48)
			validAfter := and(shr(208, validationData), MAX_UINT48)
		}
	}

	function isFailed(ValidationData validationData) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(validationData, 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
		}
	}

	function intersect(ValidationData a, ValidationData b) internal pure returns (ValidationData validationData) {
		assembly ("memory-safe") {
			let sum := shl(0x60, add(a, b))
			switch or(
				iszero(and(xor(a, b), 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)),
				or(eq(sum, shl(0x60, a)), eq(sum, shl(0x60, b)))
			)
			case 0x01 {
				validationData := and(or(a, b), 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
				// validAfter
				let a_vd := and(0xffffffffffff0000000000000000000000000000000000000000000000000000, a)
				let b_vd := and(0xffffffffffff0000000000000000000000000000000000000000000000000000, b)
				validationData := or(validationData, xor(a_vd, mul(xor(a_vd, b_vd), gt(b_vd, a_vd))))
				// validUntil
				a_vd := and(0x000000000000ffffffffffff0000000000000000000000000000000000000000, a)
				if iszero(a_vd) {
					a_vd := 0x000000000000ffffffffffff0000000000000000000000000000000000000000
				}
				b_vd := and(0x000000000000ffffffffffff0000000000000000000000000000000000000000, b)
				if iszero(b_vd) {
					b_vd := 0x000000000000ffffffffffff0000000000000000000000000000000000000000
				}
				let until := xor(a_vd, mul(xor(a_vd, b_vd), lt(b_vd, a_vd)))
				if iszero(until) {
					until := 0x000000000000ffffffffffff0000000000000000000000000000000000000000
				}
				validationData := or(validationData, until)
			}
			default {
				validationData := 0x01
			}
		}
	}
}
