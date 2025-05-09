// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortex} from "src/interfaces/IVortex.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {ValidatorBase} from "./ValidatorBase.sol";

/// @title ERC7739Validator
/// @notice Provides nested typed data sign support for ERC-7579 validators
/// @dev Modified from https://github.com/erc7579/erc7739Validator/blob/main/src/ERC7739Validator.sol
abstract contract ERC7739Validator is ValidatorBase {
	using AccountIdLib for string;

	/// @notice Thrown when the provided signature is invalid
	error InvalidSignature();

	/// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
	bytes32 internal constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

	/// @dev keccak256("PersonalSign(bytes prefixed)")
	bytes32 internal constant PERSONAL_SIGN_TYPEHASH =
		0x983e65e5148e570cd828ead231ee759a8d7958721a768f93bc4483ba005c32de;

	address internal constant MULTICALLER_WITH_SIGNER = 0x000000000000D9ECebf3C23529de49815Dac1c4c;

	bytes4 internal constant SUPPORTS_ERC7739 = 0x77390000;
	bytes4 internal constant SUPPORTS_ERC7739_V1 = 0x77390001;

	/// @dev Backwards compatibility stuff
	/// For automatic detection that the smart account supports the nested EIP-712 workflow.
	/// By default, it returns `bytes32(bytes4(keccak256("supportsNestedTypedDataSign()")))`,
	/// denoting support for the default behavior, as implemented in
	/// `_erc1271IsValidSignatureViaNestedEIP712`, which is called in `isValidSignature`.
	/// Future extensions should return a different non-zero `result` to denote different behavior.
	/// This method intentionally returns bytes32 to allow freedom for future extensions.
	function supportsNestedTypedDataSign() public view virtual returns (bytes32 result) {
		result = bytes4(0xd620c85a);
	}

	/// @dev Returns whether the `signature` is valid for the `hash.
	/// Use this in your validator's `isValidSignatureWithSender` implementation.
	function _erc1271IsValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bytes4 magicValue) {
		// detection request
		// this check only takes 17 gas units
		// in theory, it can be moved out of this function so it doesn't apply to every
		// isValidSignatureWithSender() call, but it would require an additional standard
		// interface for SA to check if the IValidator supports ERC-7739
		// while isValidSignatureWithSender() is specified by ERC-7579, so
		// it makes sense to use it in SA to check if the validator supports ERC-7739
		unchecked {
			if (signature.length == uint256(0)) {
				// Forces the compiler to optimize for smaller bytecode size.
				if (uint256(hash) == (~signature.length / 0xffff) * 0x7739) return SUPPORTS_ERC7739_V1;
			}
		}

		// sig malleability prevention
		assembly ("memory-safe") {
			if gt(
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

	/// @dev Performs the signature validation without nested EIP-712 if the caller is
	/// a safe caller. A safe caller must include the address of this account in the hash.
	function _erc1271IsValidSignatureViaSafeCaller(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool result) {
		if (_erc1271CallerIsSafe(sender)) result = _erc1271IsValidSignatureNowCalldata(hash, signature);
	}

	/// @dev ERC1271 signature validation (Nested EIP-712 workflow).
	///
	/// This uses ECDSA recovery by default (see: `_erc1271IsValidSignatureNowCalldata`).
	/// It also uses a nested EIP-712 approach to prevent signature replays when a single EOA
	/// owns multiple smart contract accounts,
	/// while still enabling wallet UIs (e.g. Metamask) to show the EIP-712 values.
	///
	/// Crafted for phishing resistance, efficiency, flexibility.
	/// __________________________________________________________________________________________
	///
	/// Glossary:
	///
	/// - `APP_DOMAIN_SEPARATOR`: The domain separator of the `hash` passed in by the application.
	///   Provided by the front end. Intended to be the domain separator of the contract
	///   that will call `isValidSignature` on this account.
	///
	/// - `ACCOUNT_DOMAIN_SEPARATOR`: The domain separator of this account.
	///   See: `EIP712._domainSeparator()`.
	/// __________________________________________________________________________________________
	///
	/// For the `TypedDataSign` workflow, the final hash will be:
	/// ```
	///     keccak256(\x19\x01 ‖ APP_DOMAIN_SEPARATOR ‖
	///         hashStruct(TypedDataSign({
	///             contents: hashStruct(originalStruct),
	///             name: keccak256(bytes(eip712Domain().name)),
	///             version: keccak256(bytes(eip712Domain().version)),
	///             chainId: eip712Domain().chainId,
	///             verifyingContract: eip712Domain().verifyingContract,
	///             salt: eip712Domain().salt
	///         }))
	///     )
	/// ```
	/// where `‖` denotes the concatenation operator for bytes.
	/// The order of the fields is important: `contents` comes before `name`.
	///
	/// The signature will be `r ‖ s ‖ v ‖ APP_DOMAIN_SEPARATOR ‖
	///     contents ‖ contentsDescription ‖ uint16(contentsDescription.length)`,
	/// where:
	/// - `contents` is the bytes32 struct hash of the original struct.
	/// - `contentsDescription` can be either:
	///     a) `contentsType` (implicit mode)
	///         where `contentsType` starts with `contentsName`.
	///     b) `contentsType ‖ contentsName` (explicit mode)
	///         where `contentsType` may not necessarily start with `contentsName`.
	///
	/// The `APP_DOMAIN_SEPARATOR` and `contents` will be used to verify if `hash` is indeed correct.
	/// __________________________________________________________________________________________
	///
	/// For the `PersonalSign` workflow, the final hash will be:
	/// ```
	///     keccak256(\x19\x01 ‖ ACCOUNT_DOMAIN_SEPARATOR ‖
	///         hashStruct(PersonalSign({
	///             prefixed: keccak256(bytes(\x19Ethereum Signed Message:\n ‖
	///                 base10(bytes(someString).length) ‖ someString))
	///         }))
	///     )
	/// ```
	/// where `‖` denotes the concatenation operator for bytes.
	///
	/// The `PersonalSign` type hash will be `keccak256("PersonalSign(bytes prefixed)")`.
	/// The signature will be `r ‖ s ‖ v`.
	/// __________________________________________________________________________________________
	///
	/// For demo and typescript code, see:
	/// - https://github.com/junomonster/nested-eip-712
	/// - https://github.com/frangio/eip712-wrapper-for-eip1271
	///
	/// Their nomenclature may differ from ours, although the high-level idea is similar.
	///
	/// Of course, if you have control over the codebase of the wallet client(s) too,
	/// you can choose a more minimalistic signature scheme like
	/// `keccak256(abi.encode(address(this), hash))` instead of all these acrobatics.
	/// All these are just for widespread out-of-the-box compatibility with other wallet clients.
	/// We want to create bazaars, not walled castles.
	/// And we'll use push the Turing Completeness of the EVM to the limits to do so.
	function _erc1271IsValidSignatureViaNestedEIP712(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool result) {
		// bytes32 t = _typedDataSignFieldsForAccount(msg.sender);
		uint256 t = uint256(uint160(address(this)));
		// Forces the compiler to pop the variables after the scope, avoiding stack-too-deep.
		if (t != uint256(0)) {
			(string memory name, string memory version) = IVortex(msg.sender).accountId().parse();

			assembly ("memory-safe") {
				t := mload(0x40)
				// Skip 2 words for the `typedDataSignTypehash` and `contents` struct hash.
				mstore(add(t, 0x40), keccak256(add(name, 0x20), mload(name)))
				mstore(add(t, 0x60), keccak256(add(version, 0x20), mload(version)))
				mstore(add(t, 0x80), chainid())
				mstore(add(t, 0xa0), caller())
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

		if (t == uint256(0)) hash = _hashTypedDataForAccount(msg.sender, hash); // `PersonalSign` workflow.
		return _erc1271IsValidSignatureNowCalldata(hash, signature);
	}

	/// @dev Performs the signature validation without nested EIP-712 to allow for easy sign ins.
	/// This function must always return false or revert if called on-chain.
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

	/// @dev Returns whether the `msg.sender` is considered safe, such
	/// that we don't need to use the nested EIP-712 workflow.
	/// Override to return true for more callers.
	/// See: https://mirror.xyz/curiousapple.eth/pFqAdW2LiJ-6S4sg_u1z08k4vK6BCJ33LcyXpnNb8yU
	function _erc1271CallerIsSafe(address sender) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			// The canonical `MulticallerWithSigner` at 0x000000000000D9ECebf3C23529de49815Dac1c4c
			// is known to include the account in the hash to be signed.
			result := or(eq(sender, caller()), eq(sender, MULTICALLER_WITH_SIGNER))
		}
	}

	/// @dev Unwraps and returns the signature.
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
				result.offset := add(ptr, 0x20)
				result.length := calldataload(ptr)
			}
		}
	}

	/// @dev Hashes typed data according to eip-712; uses account's domain separator
	/// @param account the smart account, who's domain separator will be used
	/// @param structHash the typed data struct hash
	function _hashTypedDataForAccount(
		address account,
		bytes32 structHash
	) internal view virtual returns (bytes32 digest) {
		(string memory name, string memory version) = IVortex(account).accountId().parse();

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(ptr, DOMAIN_TYPEHASH)
			mstore(add(ptr, 0x20), keccak256(add(name, 0x20), mload(name)))
			mstore(add(ptr, 0x40), keccak256(add(version, 0x20), mload(version)))
			mstore(add(ptr, 0x60), chainid())
			mstore(add(ptr, 0x80), account)
			digest := keccak256(ptr, 0xa0) // domain separator

			mstore(0x00, 0x1901000000000000)
			mstore(0x1a, digest)
			mstore(0x3a, structHash)
			digest := keccak256(0x18, 0x42) // hash typed data

			mstore(0x3a, 0x00)
		}
	}

	/// @dev Returns whether the `hash` and `signature` are valid.
	///      Obtains the authorized signer's credentials and calls some
	///      module's specific internal function to validate the signature
	///      against credentials.
	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool);
}
