// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR} from "src/types/Constants.sol";
import {ModuleType} from "src/types/Types.sol";

/// @title AccessControl

abstract contract AccessControl {
	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;

	modifier onlyEntryPoint() {
		_checkEntryPoint();
		_;
	}

	modifier onlyEntryPointOrSelf() {
		_checkEntryPointOrSelf();
		_;
	}

	modifier onlyExecutor() {
		_checkModule(msg.sender, MODULE_TYPE_EXECUTOR);
		_;
	}

	modifier onlyValidator(address validator) {
		_checkModule(validator, MODULE_TYPE_VALIDATOR);
		_;
	}

	function _isEntryPointOrSelf() internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			result := or(eq(caller(), ENTRYPOINT), eq(caller(), address()))
		}
	}

	function _checkEntryPoint() internal view virtual {
		assembly ("memory-safe") {
			if xor(caller(), ENTRYPOINT) {
				mstore(0x00, 0x8e4a23d6) // Unauthorized(address)
				mstore(0x20, shr(0x60, shl(0x60, caller())))
				revert(0x1c, 0x24)
			}
		}
	}

	function _checkEntryPointOrSelf() internal view virtual {
		assembly ("memory-safe") {
			if and(xor(caller(), ENTRYPOINT), xor(caller(), address())) {
				mstore(0x00, 0x8e4a23d6) // Unauthorized(address)
				mstore(0x20, shr(0x60, shl(0x60, caller())))
				revert(0x1c, 0x24)
			}
		}
	}

	function _checkModule(address module, ModuleType moduleTypeId) internal view virtual;
}
