// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title SignatureChecker
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/SignatureCheckerLib.sol

library SignatureChecker {
	function isValidSignatureNow(
		address signer,
		bytes32 hash,
		bytes calldata signature
	) internal view returns (bool result) {
		assembly ("memory-safe") {
			// prettier-ignore
			for { } 0x01 { } {
				if or(
					iszero(signer),
					gt(
						calldataload(add(signature.offset, 0x20)),
						0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
					)
				) {
					break
				}

				let ptr := mload(0x40)

				if iszero(extcodesize(signer)) {
					switch signature.length
					case 0x40 {
						let vs := calldataload(add(signature.offset, 0x20))
						mstore(0x20, add(shr(0xff, vs), 0x1b))
						mstore(0x40, calldataload(signature.offset))
						mstore(0x60, shr(0x01, shl(0x01, vs)))
					}
					case 0x41 {
						mstore(0x20, byte(0x00, calldataload(add(signature.offset, 0x40))))
						calldatacopy(0x40, signature.offset, 0x40)
					}
					default {
						break
					}

					mstore(0x00, hash)
					let recovered := mload(staticcall(gas(), 0x01, 0x00, 0x80, 0x01, 0x20))
					result := gt(returndatasize(), shl(0x60, xor(signer, recovered)))

					mstore(0x60, 0x00)
					mstore(0x40, ptr)
					break
				}

				let selector := shl(0xe0, 0x1626ba7e)
				mstore(ptr, selector)
				mstore(add(ptr, 0x04), hash)
				mstore(add(ptr, 0x24), 0x40)
				mstore(add(ptr, 0x44), signature.length)
				calldatacopy(add(ptr, 0x64), signature.offset, signature.length)

				result := and(
					eq(mload(0x00), selector),
					staticcall(gas(), signer, ptr, add(signature.length, 0x64), 0x00, 0x20)
				)
				break
			}
		}
	}

	function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			mstore(0x00, "\x19Ethereum Signed Message:\n32")
			mstore(0x1c, messageHash)
			digest := keccak256(0x00, 0x3c)
		}
	}

	function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let length := mload(message)
			let offset := 0x20

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
}
