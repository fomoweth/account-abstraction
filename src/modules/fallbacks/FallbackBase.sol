// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/modules/IERC7579Modules.sol";
import {ModuleType, MODULE_TYPE_FALLBACK} from "src/types/ModuleType.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title FallbackBase

abstract contract FallbackBase is IFallback, ModuleBase {
	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_FALLBACK;
	}

	function _msgSender() internal pure virtual returns (address sender) {
		assembly ("memory-safe") {
			if lt(calldatasize(), 0x14) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			sender := shr(0x60, calldataload(sub(calldatasize(), 0x14)))
		}
	}
}
