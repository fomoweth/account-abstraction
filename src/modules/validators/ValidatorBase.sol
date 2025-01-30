// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IValidator} from "src/interfaces/IERC7579Modules.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title ValidatorBase

abstract contract ValidatorBase is IValidator, ModuleBase {
	bytes1 internal constant MODE_VALIDATION = 0x00;
	bytes1 internal constant MODE_MODULE_ENABLE = 0x01;

	function packValidationData(
		bool sigFailed,
		uint48 validUntil,
		uint48 validAfter
	) internal pure returns (uint256 validationData) {
		assembly ("memory-safe") {
			validationData := or(add(shl(208, validAfter), shl(160, validUntil)), and(iszero(iszero(sigFailed)), 0xff))
		}
	}

	function parseValidationData(
		uint256 validationData
	) internal pure returns (bool sigFailed, uint48 validUntil, uint48 validAfter) {
		assembly ("memory-safe") {
			sigFailed := and(validationData, 0x01)
			validUntil := and(shr(160, validationData), sub(shl(48, 1), 1))
			validAfter := and(shr(208, validationData), sub(shl(48, 1), 1))
		}
	}

	function isModuleType(uint256 moduleTypeId) external pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR;
	}
}
