// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";

/// @title ERC1271
/// @notice Provides functions for nested typed data sign support for ERC-7579 validators

abstract contract ERC1271 {
	using AccountIdLib for string;

	/// @dev keccak256("PersonalSign(bytes prefixed)")
	bytes32 internal constant PERSONAL_SIGN_TYPEHASH =
		0x983e65e5148e570cd828ead231ee759a8d7958721a768f93bc4483ba005c32de;

	address internal constant MULTICALLER_WITH_SIGNER = 0x000000000000D9ECebf3C23529de49815Dac1c4c;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	bytes4 internal constant ERC7739_SUPPORTS = 0x77390000;
	bytes4 internal constant ERC7739_SUPPORTS_V1 = 0x77390001;

	function supportsNestedTypedDataSign() public view virtual returns (bytes32) {
		return bytes4(0xd620c85a);
	}

	function _erc1271IsValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bytes4 magicValue) {
		// For automatic detection that the smart account supports the nested EIP-712 workflow,
		// See: https://eips.ethereum.org/EIPS/eip-7739.
		// If `hash` is `0x7739...7739`, returns `bytes4(0x77390001)`.
		// The returned number MAY be increased in future ERC7739 versions.
		unchecked {
			if (signature.length == uint256(0)) {
				if (uint256(hash) == (~signature.length / 0xffff) * 0x7739) return ERC7739_SUPPORTS_V1;
			}
		}

		assembly ("memory-safe") {
			if gt(
				// same as `s := mload(add(signature, 0x40))` but for calldata
				calldataload(add(signature.offset, 0x20)),
				0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
			) {
				mstore(0x00, 0x8baa579f) // InvalidSignature()
				revert(0x1c, 0x04)
			}
		}

		bool success = _erc1271IsValidSignatureViaSafeCaller(sender, hash, signature) ||
			_erc1271IsValidSignatureViaNestedEIP712(hash, signature) ||
			_erc1271IsValidSignatureViaRPC(hash, signature);

		assembly ("memory-safe") {
			// `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
			// We use `0xffffffff` for invalid, in convention with the reference implementation.
			magicValue := shl(0xe0, or(0x1626ba7e, sub(0x00, iszero(success))))
		}
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			result := or(eq(sender, caller()), eq(sender, MULTICALLER_WITH_SIGNER))
		}
	}

	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool);

	function _erc1271UnwrapSignature(bytes calldata signature) internal view virtual returns (bytes calldata result) {
		result = signature;
		assembly ("memory-safe") {
			// Unwraps the ERC6492 wrapper if it exists.
			// See: https://eips.ethereum.org/EIPS/eip-6492
			if eq(
				calldataload(add(result.offset, sub(result.length, 0x20))),
				mul(0x6492, div(not(shr(address(), address())), 0xffff)) // `0x6492...6492`.
			) {
				let ptr := add(result.offset, calldataload(add(result.offset, 0x40)))
				result.length := calldataload(ptr)
				result.offset := add(ptr, 0x20)
			}
		}
	}

	function _erc1271IsValidSignatureViaSafeCaller(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool result) {
		if (_erc1271CallerIsSafe(sender)) result = _erc1271IsValidSignatureNowCalldata(hash, signature);
	}

	function _erc1271IsValidSignatureViaNestedEIP712(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool result) {
		uint256 t = uint256(uint160(address(this)));

		if (t != uint256(0)) {
			string memory name;
			string memory version;

			try IERC7579Account(msg.sender).accountId() returns (string memory accountId) {
				(name, version) = accountId.parse();
			} catch {
				return false;
			}

			assembly ("memory-safe") {
				t := mload(0x40)
				// Skip 2 words for the `typedDataSignTypehash` and `contents` struct hash.
				mstore(add(t, 0x40), keccak256(add(name, 0x20), mload(name)))
				mstore(add(t, 0x60), keccak256(add(version, 0x20), mload(version)))
				mstore(add(t, 0x80), chainid())
				mstore(add(t, 0xa0), shr(0x60, shl(0x60, caller())))
				mstore(add(t, 0xc0), 0x00)
				mstore(0x40, add(t, 0xe0))
			}
		}

		// prettier-ignore
		assembly ("memory-safe") {
			let m := mload(0x40)
			// `c` is `contentsDescription.length`, which is stored in the last 2 bytes of the signature.
			let c := shr(0xf0, calldataload(add(signature.offset, sub(signature.length, 0x02))))
			for { } 0x01 { } {
                let l := add(0x42, c) // Total length of appended data (32 + 32 + c + 2).
                let o := add(signature.offset, sub(signature.length, l)) // Offset of appended data.
                mstore(0x00, 0x1901) // Store the "\x19\x01" prefix.
                calldatacopy(0x20, o, 0x40) // Copy the `APP_DOMAIN_SEPARATOR` and `contents` struct hash.
                // Use the `PersonalSign` workflow if the reconstructed hash doesn't match,
                // or if the appended data is invalid, i.e.
                // `appendedData.length > signature.length || contentsDescription.length == 0`.
                if or(xor(keccak256(0x1e, 0x42), hash), or(lt(signature.length, l), iszero(c))) {
                    t := 0x00 // Set `t` to 0, denoting that we need to `hash = _hashTypedData(hash)`.
                    mstore(t, PERSONAL_SIGN_TYPEHASH)
                    mstore(0x20, hash) // Store the `prefixed`.
                    hash := keccak256(t, 0x40) // Compute the `PersonalSign` struct hash.
                    break
                }
                // Else, use the `TypedDataSign` workflow.
                // `TypedDataSign({ContentsName} contents,string name,...){ContentsType}`.
                mstore(m, "TypedDataSign(") // Store the start of `TypedDataSign`'s type encoding.
                let p := add(m, 0x0e) // Advance 14 bytes to skip "TypedDataSign(".
                calldatacopy(p, add(o, 0x40), c) // Copy `contentsName`, optimistically.
                mstore(add(p, c), 0x28) // Store a '(' after the end.
                if iszero(eq(byte(0x00, mload(sub(add(p, c), 0x01))), 0x29)) {
                    let e // Length of `contentsName` in explicit mode.
                    for { let q := sub(add(p, c), 0x01) } 0x01 { } {
                        e := add(e, 0x01) // Scan backwards until we encounter a ')'.
                        if iszero(gt(lt(e, c), eq(byte(0x00, mload(sub(q, e))), 0x29))) { break }
                    }
                    c := sub(c, e) // Truncate `contentsDescription` to `contentsType`.
                    calldatacopy(p, add(add(o, 0x40), c), e) // Copy `contentsName`.
                    mstore8(add(p, e), 0x28) // Store a '(' exactly right after the end.
                }
                // `d & 1 == 1` means that `contentsName` is invalid.
                let d := shr(byte(0x00, mload(p)), 0x7fffffe000000000000010000000000) // Starts with `[a-z(]`.
                // Advance `p` until we encounter '('.
                for { } iszero(eq(byte(0x00, mload(p)), 0x28)) { p := add(p, 0x01) } {
                    d := or(shr(byte(0x00, mload(p)), 0x120100000001), d) // Has a byte in ", )\x00".
                }
                mstore(p, " contents,string name,string") // Store the rest of the encoding.
                mstore(add(p, 0x1c), " version,uint256 chainId,address")
                mstore(add(p, 0x3c), " verifyingContract,bytes32 salt)")
                p := add(p, 0x5c)
                calldatacopy(p, add(o, 0x40), c) // Copy `contentsType`.
                // Fill in the missing fields of the `TypedDataSign`.
                calldatacopy(t, o, 0x40) // Copy the `contents` struct hash to `add(t, 0x20)`.
                mstore(t, keccak256(m, sub(add(p, c), m))) // Store `typedDataSignTypehash`.
                // The "\x19\x01" prefix is already at 0x00.
                // `APP_DOMAIN_SEPARATOR` is already at 0x20.
                mstore(0x40, keccak256(t, 0xe0)) // `hashStruct(typedDataSign)`.
                // Compute the final hash, corrupted if `contentsName` is invalid.
                hash := keccak256(0x1e, add(0x42, and(0x01, d)))
                signature.length := sub(signature.length, l) // Truncate the signature.
                break
            }

			mstore(0x40, m)
		}

		if (t == uint256(0)) hash = _hashTypedData(hash); // `PersonalSign` workflow.
		result = _erc1271IsValidSignatureNowCalldata(hash, signature);
	}

	function _erc1271IsValidSignatureViaRPC(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool result) {
		// Non-zero gasprice is a heuristic to check if a call is on-chain,
		// but we can't fully depend on it because it can be manipulated.
		// See: https://x.com/NoahCitron/status/1580359718341484544
		if (tx.gasprice == uint256(0)) {
			// prettier-ignore
			assembly ("memory-safe") {
				mstore(gasprice(), gasprice())
				// See: https://gist.github.com/Vectorized/3c9b63524d57492b265454f62d895f71
				let b := 0x000000000000378eDCD5B5B0A24f5342d8C10485 // Basefee contract,
				pop(staticcall(0xffff, b, codesize(), gasprice(), gasprice(), 0x20))
				// If `gasprice < basefee`, the call cannot be on-chain, and we can skip the gas burn.
				if iszero(mload(gasprice())) {
                    let m := mload(0x40)
                    mstore(gasprice(), 0x1626ba7e) // `isValidSignature(bytes32,bytes)`.
                    mstore(0x20, b) // Recycle `b` to denote if we need to burn gas.
                    mstore(0x40, 0x40)
                    let gasToBurn := or(add(0xffff, gaslimit()), gaslimit())
                    // Burns gas computationally efficiently. Also, requires that `gas > gasToBurn`.
                    if or(eq(hash, b), lt(gas(), gasToBurn)) { invalid() }
                    // Make a call to this with `b`, efficiently burning the gas provided.
                    // No valid transaction can consume more than the gaslimit.
                    // See: https://ethereum.github.io/yellowpaper/paper.pdf
                    // Most RPCs perform calls with a gas budget greater than the gaslimit.
                    pop(staticcall(gasToBurn, address(), 0x1c, 0x64, gasprice(), gasprice()))
                    mstore(0x40, m)
                }
			}

			result = _erc1271IsValidSignatureNowCalldata(hash, signature);
		}
	}

	function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x3644e51500000000000000000000000000000000000000000000000000000000) // DOMAIN_SEPARATOR()

			if iszero(staticcall(5000, caller(), ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x1a, mload(0x00))
			mstore(0x00, 0x1901000000000000)
			mstore(0x3a, structHash)
			digest := keccak256(0x18, 0x42)
			mstore(0x3a, 0x00)
		}
	}
}
