// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/IERC7579Modules.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title FallbackBase

abstract contract FallbackBase is IFallback, ModuleBase {
	function _msgSender() internal view virtual returns (address sender) {
		assembly ("memory-safe") {
			switch lt(calldatasize(), 0x14)
			case 0x00 {
				sender := shr(0x60, calldataload(sub(calldatasize(), 0x14)))
			}
			default {
				sender := caller()
			}
		}
	}

	fallback() external payable virtual {
		assembly ("memory-safe") {
			mstore(0x00, 0xf6f5069b) // ForbiddenFallback()
			revert(0x1c, 0x04)
		}
	}

	receive() external payable virtual {}
}
