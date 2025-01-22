// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Ownable
/// @notice Simple single owner authorization mixin
/// @dev Modified from https://github.com/vectorized/solady/blob/main/src/auth/Ownable.sol

abstract contract Ownable {
	/// @dev keccak256(bytes("OwnershipTransferred(address,address)"))
	uint256 private constant OWNERSHIP_TRANSFERRED_TOPIC =
		0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

	/// @dev bytes32(~uint256(uint32(bytes4(keccak256("_OWNER_SLOT_NOT")))))
	bytes32 internal constant OWNER_SLOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;

	modifier onlyOwner() {
		_checkOwner();
		_;
	}

	function owner() public view virtual returns (address res) {
		assembly ("memory-safe") {
			res := sload(OWNER_SLOT)
		}
	}

	function transferOwnership(address newOwner) public payable virtual onlyOwner {
		_checkNewOwner(newOwner);
		_setOwner(newOwner);
	}

	function renounceOwnership() public payable virtual onlyOwner {
		_setOwner(address(0));
	}

	function _initializeOwner(address initialOwner) internal virtual {
		_checkNewOwner(initialOwner);

		assembly ("memory-safe") {
			if sload(OWNER_SLOT) {
				mstore(0x00, 0x0dc149f0) // AlreadyInitialized()
				revert(0x1c, 0x04)
			}

			initialOwner := shr(0x60, shl(0x60, initialOwner))
			log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, 0x00, initialOwner)
			sstore(OWNER_SLOT, initialOwner)
		}
	}

	function _setOwner(address newOwner) internal virtual {
		assembly ("memory-safe") {
			newOwner := shr(0x60, shl(0x60, newOwner))
			log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, sload(OWNER_SLOT), newOwner)
			sstore(OWNER_SLOT, newOwner)
		}
	}

	function _checkOwner() internal view virtual {
		assembly ("memory-safe") {
			if xor(caller(), sload(OWNER_SLOT)) {
				mstore(0x00, 0x82b42900) // Unauthorized()
				revert(0x1c, 0x04)
			}
		}
	}

	function _checkNewOwner(address newOwner) internal pure virtual {
		assembly ("memory-safe") {
			if iszero(shl(0x60, newOwner)) {
				mstore(0x00, 0x54a56786) // InvalidNewOwner()
				revert(0x1c, 0x04)
			}
		}
	}
}
