// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type ValidationData is uint256;

type ValidAfter is uint48;

type ValidUntil is uint48;

using ValidationDataLib for ValidationData global;
using ValidationDataLib for ValidAfter global;

/// @title ValidationDataLib

library ValidationDataLib {
	function getValidationResult(ValidationData validationData) internal pure returns (address result) {
		assembly ("memory-safe") {
			result := and(validationData, 0xffffffffffffffffffffffffffffffffffffffff)
		}
	}

	function packValidationData(
		ValidAfter validAfter,
		ValidUntil validUntil
	) internal pure returns (uint256 validationData) {
		assembly ("memory-safe") {
			validationData := or(shl(0xd0, validAfter), shl(0xa0, validUntil))
		}
	}

	function parseValidationData(
		ValidationData validationData
	) internal pure returns (ValidAfter validAfter, ValidUntil validUntil, address result) {
		assembly ("memory-safe") {
			result := validationData
			validUntil := and(shr(0xa0, validationData), 0xffffffffffff)
			switch iszero(validUntil)
			case 0x01 {
				validUntil := 0xffffffffffff
			}
			validAfter := shr(0xd0, validationData)
		}
	}
}
