// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AccessControl
/// @notice Provides modifiers for restricting access control to the contract and its entry points
abstract contract AccessControl {
	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

	/// @notice Restricts access to the EntryPoint
	modifier onlyEntryPoint() virtual {
		_checkEntryPoint();
		_;
	}

	/// @notice Restricts access to EntryPoint or the account itself
	modifier onlyEntryPointOrSelf() virtual {
		_checkEntryPointOrSelf();
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
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
	}

	function _checkEntryPointOrSelf() internal view virtual {
		assembly ("memory-safe") {
			if and(xor(caller(), ENTRYPOINT), xor(caller(), address())) {
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
	}
}
