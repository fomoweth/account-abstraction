// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ValidationData} from "src/types/ValidationData.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title ValidatorBase
/// @notice ERC-7579 validator module base interface
abstract contract ValidatorBase is ModuleBase {
	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	ValidationData internal constant VALIDATION_SUCCESS = ValidationData.wrap(0x00);
	ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(0x01);
}
