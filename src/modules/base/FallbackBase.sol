// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/IERC7579Modules.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title FallbackBase
/// @notice ERC-7579 fallback module base interface
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
}
