// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title MessageHashUtils
/// @notice Provides signature message hash utilities for producing digests to be consumed by ECDSA recovery or signing
/// @dev Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MessageHashUtils.sol
library MessageHashUtils {
	/// @dev Returns the keccak256 digest of an ERC-191 signed data with version `0x45` (`personal_sign` messages)
	function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			mstore(0x00, "\x19Ethereum Signed Message:\n32")
			mstore(0x1c, messageHash)
			digest := keccak256(0x00, 0x3c)
		}
	}

	/// @dev Returns the keccak256 digest of an ERC-191 signed data with version `0x45` (`personal_sign` messages)
	function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let offset := 0x20
			let length := mload(message)

			mstore(offset, "\x19Ethereum Signed Message:\n")
			mstore(0x00, 0x00)

			// prettier-ignore
			for { let guard := length } 0x01 { } {
				offset := sub(offset, 0x01)
				mstore8(offset, add(0x30, mod(guard, 0x0a)))
				guard := div(guard, 0x0a)
				if iszero(guard) { break }
			}

			offset := sub(0x3a, offset)
			returndatacopy(returndatasize(), returndatasize(), gt(offset, 0x20))
			mstore(message, or(mload(0x00), mload(offset)))
			digest := keccak256(add(message, sub(0x20, offset)), add(offset, length))
			mstore(message, length)
		}
	}

	/// @dev Returns the keccak256 digest of an ERC-191 signed data with version `0x00` (data with intended validator)
	function toDataWithIntendedValidatorHash(
		address validator,
		bytes memory data
	) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, hex"19_00")
			mstore(add(ptr, 0x02), shl(0x60, validator))

			let offset := add(data, 0x20)
			let length := mload(data)
			let guard := add(offset, length)

			// prettier-ignore
			for { let pos := add(ptr, 0x16) } lt(offset, guard) { offset := add(offset, 0x20) pos := add(pos, 0x20) } {
				mstore(pos, mload(offset))
			}

			digest := keccak256(ptr, add(length, 0x16))
			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))
		}
	}

	/// @dev Variant of {toDataWithIntendedValidatorHash-address-bytes} optimized for cases where `data` is a bytes32
	function toDataWithIntendedValidatorHash(
		address validator,
		bytes32 messageHash
	) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			mstore(0x00, hex"19_00")
			mstore(0x02, shl(0x60, validator))
			mstore(0x16, messageHash)
			digest := keccak256(0x00, 0x36)
		}
	}

	/// @dev Returns the keccak256 digest of an EIP-712 typed data (ERC-191 version `0x01`)
	function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(ptr, hex"19_01")
			mstore(add(ptr, 0x02), domainSeparator)
			mstore(add(ptr, 0x22), structHash)
			digest := keccak256(ptr, 0x42)
		}
	}
}
