// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type ValidationMode is bytes1;

type BatchId is bytes3;

using ValidationModeLib for ValidationMode global;
using {eqValidationMode as ==, neqValidationMode as !=} for ValidationMode global;
using {eqBatchId as ==, neqBatchId as !=} for BatchId global;

function eqValidationMode(ValidationMode x, ValidationMode y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := eq(x, y)
	}
}

function neqValidationMode(ValidationMode x, ValidationMode y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := xor(x, y)
	}
}

function eqBatchId(BatchId x, BatchId y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := eq(x, y)
	}
}

function neqBatchId(BatchId x, BatchId y) pure returns (bool flag) {
	assembly ("memory-safe") {
		flag := xor(x, y)
	}
}

/// @title ValidationModeLib
/// @notice Provides functions for encoding and parsing nonce key

library ValidationModeLib {
	ValidationMode internal constant MODE_VALIDATION = ValidationMode.wrap(0x00);
	ValidationMode internal constant MODE_MODULE_ENABLE = ValidationMode.wrap(0x01);

	BatchId internal constant BATCH_ID_DEFAULT = BatchId.wrap(bytes3(0));

	function getValidator(uint256 nonce) internal pure returns (address validator) {
		assembly ("memory-safe") {
			validator := shr(0x60, shl(0x20, nonce))
		}
	}

	function isModuleEnableMode(uint256 nonce) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			// MODE_VALIDATION: 0x00
			// MODE_MODULE_ENABLE: 0x01
			flag := eq(byte(0x03, nonce), 0x01)
		}
	}

	function encodeNonceKey(ValidationMode mode, address validator) internal pure returns (uint192 key) {
		assembly ("memory-safe") {
			key := or(shr(0x58, mode), validator)
		}
	}

	function encodeNonceKey(
		ValidationMode mode,
		address validator,
		BatchId batchId
	) internal pure returns (uint192 key) {
		assembly ("memory-safe") {
			key := or(shr(0x58, mode), validator)
			key := or(shr(0x40, batchId), key)
		}
	}
}
