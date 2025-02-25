// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStatelessValidator} from "src/interfaces/modules/IERC7579Modules.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title StatelessValidatorBase

abstract contract StatelessValidatorBase is IStatelessValidator, ModuleBase {
	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == TYPE_STATELESS_VALIDATOR;
	}
}
