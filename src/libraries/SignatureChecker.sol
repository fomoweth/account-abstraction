// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title SignatureChecker
/// @notice Signature verification helper that supports both ECDSA signatures from EOAs and ERC1271 signatures
/// @dev Modified from https://github.com/Vectorized/solady/blob/main/src/utils/SignatureCheckerLib.sol
library SignatureChecker {
	/// @dev Used for checking the malleability of the signature.
	uint256 private constant HALF_N = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

	/// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
	bytes4 private constant MAGIC_VALUE = 0x1626ba7e;

	/// @dev Returns whether `signature` is valid for `signer` and `hash`
	function isValidSignatureNow(
		address signer,
		bytes32 hash,
		bytes memory signature
	) internal view returns (bool result) {
		assembly ("memory-safe") {
			// prettier-ignore
			for { } 0x01 { } {
				if or(iszero(shl(0x60, signer)), gt(mload(add(signature, 0x40)), HALF_N)) { break }

				let ptr := mload(0x40)

				if iszero(extcodesize(signer)) {
					switch mload(signature)
					case 64 {
						let vs := mload(add(signature, 0x40))
						mstore(0x20, add(shr(0xff, vs), 0x1b))
						mstore(0x60, shr(0x01, shl(0x01, vs)))
					}
					case 65 {
						mstore(0x20, byte(0x00, mload(add(signature, 0x60))))
						mstore(0x60, mload(add(signature, 0x40)))
					}
					default { break }
					
					mstore(0x00, hash)
					mstore(0x40, mload(add(signature, 0x20)))
					
					let recovered := mload(staticcall(gas(), 0x01, 0x00, 0x80, 0x01, 0x20))
					result := gt(returndatasize(), shl(0x60, xor(signer, recovered)))

					mstore(0x60, 0x00)
					mstore(0x40, ptr)
					break
				}

				mstore(ptr, MAGIC_VALUE)
				mstore(add(ptr, 0x04), hash)
				let d := add(ptr, 0x24)
				mstore(d, 0x40)

				let length := add(0x20, mload(signature))
				let copied := staticcall(gas(), 0x04, signature, length, add(ptr, 0x44), length)

				result := and(eq(mload(d), MAGIC_VALUE), and(copied, staticcall(gas(), signer, ptr, add(returndatasize(), 0x44), d, 0x20)))
				break
			}
		}
	}

	/// @dev Returns whether `signature` is valid for `signer` and `hash`
	function isValidSignatureNowCalldata(
		address signer,
		bytes32 hash,
		bytes calldata signature
	) internal view returns (bool result) {
		assembly ("memory-safe") {
			// prettier-ignore
			for { } 0x01 { } {
				if or(iszero(shl(0x60, signer)), gt(calldataload(add(signature.offset, 0x20)), HALF_N)) { break }

				let ptr := mload(0x40)

				if iszero(extcodesize(signer)) {
					switch signature.length
					case 64 {
						let vs := calldataload(add(signature.offset, 0x20))
						mstore(0x20, add(shr(0xff, vs), 0x1b))
						mstore(0x40, calldataload(signature.offset))
						mstore(0x60, shr(0x01, shl(0x01, vs)))
					}
					case 65 {
						mstore(0x20, byte(0x00, calldataload(add(signature.offset, 0x40))))
						calldatacopy(0x40, signature.offset, 0x40)
					}
					default { break }
					
					mstore(0x00, hash)
					let recovered := mload(staticcall(gas(), 0x01, 0x00, 0x80, 0x01, 0x20))
					result := gt(returndatasize(), shl(0x60, xor(signer, recovered)))

					mstore(0x60, 0x00)
					mstore(0x40, ptr)
					break
				}

				mstore(ptr, MAGIC_VALUE)
				mstore(add(ptr, 0x04), hash)
				let d := add(ptr, 0x24)
				mstore(d, 0x40)

                mstore(add(ptr, 0x44), signature.length)
				calldatacopy(add(ptr, 0x64), signature.offset, signature.length)

				result := and(eq(mload(d), MAGIC_VALUE), staticcall(gas(), signer, ptr, add(signature.length, 0x64), d, 0x20))
				break
			}
		}
	}
}
