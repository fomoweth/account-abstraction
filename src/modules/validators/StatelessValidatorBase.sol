// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStatelessValidator} from "src/interfaces/IERC7579Modules.sol";
import {ModuleType, MODULE_TYPE_STATELESS_VALIDATOR} from "src/types/ModuleType.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title StatelessValidatorBase

abstract contract StatelessValidatorBase is IStatelessValidator, ModuleBase {
	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR;
	}
}
