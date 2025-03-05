// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/modules/IERC7579Modules.sol";
import {CallType} from "src/types/ExecutionMode.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title FallbackBase

abstract contract FallbackBase is IFallback, ModuleBase {
	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	uint256 private immutable __self = uint256(uint160(address(this)));

	modifier onlyDelegated() {
		uint256 s = __self;
		assembly ("memory-safe") {
			if eq(s, address()) {
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	modifier notDelegated() {
		uint256 s = __self;
		assembly ("memory-safe") {
			if xor(s, address()) {
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	function _isDelegated() internal view virtual returns (bool result) {
		uint256 s = __self;
		assembly ("memory-safe") {
			result := xor(s, address())
		}
	}

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
