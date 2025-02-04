// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_STATELESS_VALIDATOR} from "src/types/ModuleType.sol";
import {StatelessValidatorBase} from "./StatelessValidatorBase.sol";
import {ValidatorBase} from "./ValidatorBase.sol";

/// @title HybridValidatorBase

abstract contract HybridValidatorBase is ValidatorBase, StatelessValidatorBase {
	function isModuleType(
		ModuleType moduleTypeId
	) public pure virtual override(ValidatorBase, StatelessValidatorBase) returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR;
	}
}
