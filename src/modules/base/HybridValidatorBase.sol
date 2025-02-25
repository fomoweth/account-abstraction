// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType} from "src/types/ModuleType.sol";
import {StatelessValidatorBase} from "./StatelessValidatorBase.sol";
import {ValidatorBase} from "./ValidatorBase.sol";

/// @title HybridValidatorBase

abstract contract HybridValidatorBase is ValidatorBase, StatelessValidatorBase {
	function isModuleType(
		ModuleType moduleTypeId
	) public pure virtual override(ValidatorBase, StatelessValidatorBase) returns (bool) {
		return moduleTypeId == TYPE_VALIDATOR || moduleTypeId == TYPE_STATELESS_VALIDATOR;
	}
}
