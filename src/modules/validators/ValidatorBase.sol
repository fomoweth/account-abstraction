// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IValidator} from "src/interfaces/modules/IERC7579Modules.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR} from "src/types/ModuleType.sol";
import {ValidationData} from "src/types/ValidationData.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title ValidatorBase

abstract contract ValidatorBase is IValidator, ModuleBase {
	function encodeValidationData(
		bool failed,
		uint48 validUntil,
		uint48 validAfter
	) internal pure returns (ValidationData validationData) {
		assembly ("memory-safe") {
			validationData := or(add(shl(208, validAfter), shl(160, validUntil)), and(iszero(iszero(failed)), 0xff))
		}
	}

	function decodeValidationData(
		ValidationData validationData
	) internal pure returns (bool failed, uint48 validUntil, uint48 validAfter) {
		assembly ("memory-safe") {
			failed := and(validationData, 0x01)
			validUntil := and(shr(160, validationData), sub(shl(48, 1), 1))
			validAfter := and(shr(208, validationData), sub(shl(48, 1), 1))
		}
	}

	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR;
	}
}
