// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title CustomRevert
/// @dev Implementation from https://github.com/Uniswap/v4-core/blob/main/src/libraries/CustomRevert.sol

library CustomRevert {
	function revertWith(bytes4 selector) internal pure {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			revert(0x00, 0x04)
		}
	}

	function revertWith(bytes4 selector, address value) internal pure {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x04, and(value, 0xffffffffffffffffffffffffffffffffffffffff))
			revert(0x00, 0x24)
		}
	}

	function revertWith(bytes4 selector, bytes32 value) internal pure {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x04, value)
			revert(0x00, 0x24)
		}
	}

	function revertWith(bytes4 selector, uint256 value) internal pure {
		assembly ("memory-safe") {
			mstore(0x00, selector)
			mstore(0x04, value)
			revert(0x00, 0x24)
		}
	}
}
