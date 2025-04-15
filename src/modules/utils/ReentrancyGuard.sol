// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ReentrancyGuard
/// @notice Helps to prevent reentrant calls to a function
abstract contract ReentrancyGuard {
	error ReentrancyGuardReentrantCall();

	uint256 private constant NOT_ENTERED = 1;
	uint256 private constant ENTERED = 2;

	modifier nonReentrant() {
		_nonReentrantBefore();
		_;
		_nonReentrantAfter();
	}

	function _nonReentrantBefore() private {
		_checkReentrancyGuard();
		_setReentrancyGuard(ENTERED);
	}

	function _nonReentrantAfter() private {
		_setReentrancyGuard(NOT_ENTERED);
	}

	function _checkReentrancyGuard() private view {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))

			if eq(tload(keccak256(0x00, 0x20)), ENTERED) {
				mstore(0x00, 0x3ee5aeb5) // ReentrancyGuardReentrantCall()
				revert(0x1c, 0x04)
			}
		}
	}

	function _setReentrancyGuard(uint256 flag) private {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))
			tstore(keccak256(0x00, 0x20), flag)
		}
	}
}
