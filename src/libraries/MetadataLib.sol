// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";

/// @title MetadataLib
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/MetadataReaderLib.sol

library MetadataLib {
	uint256 internal constant GAS_STIPEND_NO_GRIEF = 100000;

	uint256 internal constant STRING_LIMIT_DEFAULT = 1000;

	function readName(Currency currency) internal view returns (string memory) {
		return _string(currency, _ptr(0x06fdde03), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
	}

	function readName(Currency currency, uint256 limit) internal view returns (string memory) {
		return _string(currency, _ptr(0x06fdde03), limit, GAS_STIPEND_NO_GRIEF);
	}

	function readName(Currency currency, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
		return _string(currency, _ptr(0x06fdde03), limit, gasStipend);
	}

	function readSymbol(Currency currency) internal view returns (string memory) {
		return _string(currency, _ptr(0x95d89b41), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
	}

	function readSymbol(Currency currency, uint256 limit) internal view returns (string memory) {
		return _string(currency, _ptr(0x95d89b41), limit, GAS_STIPEND_NO_GRIEF);
	}

	function readSymbol(Currency currency, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
		return _string(currency, _ptr(0x95d89b41), limit, gasStipend);
	}

	function readString(Currency currency, bytes memory data) internal view returns (string memory) {
		return _string(currency, _ptr(data), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
	}

	function readString(Currency currency, bytes memory data, uint256 limit) internal view returns (string memory) {
		return _string(currency, _ptr(data), limit, GAS_STIPEND_NO_GRIEF);
	}

	function readString(
		Currency currency,
		bytes memory data,
		uint256 limit,
		uint256 gasStipend
	) internal view returns (string memory) {
		return _string(currency, _ptr(data), limit, gasStipend);
	}

	function readDecimals(Currency currency) internal view returns (uint8) {
		return uint8(_uint(currency, _ptr(0x313ce567), GAS_STIPEND_NO_GRIEF));
	}

	function readDecimals(Currency currency, uint256 gasStipend) internal view returns (uint8) {
		return uint8(_uint(currency, _ptr(0x313ce567), gasStipend));
	}

	function readUint(Currency currency, bytes memory data) internal view returns (uint256) {
		return _uint(currency, _ptr(data), GAS_STIPEND_NO_GRIEF);
	}

	function readUint(Currency currency, bytes memory data, uint256 gasStipend) internal view returns (uint256) {
		return _uint(currency, _ptr(data), gasStipend);
	}

	function _string(
		Currency currency,
		bytes32 ptr,
		uint256 limit,
		uint256 gasStipend
	) private view returns (string memory result) {
		assembly ("memory-safe") {
			function min(x_, y_) -> _z {
				_z := xor(x_, mul(xor(x_, y_), lt(y_, x_)))
			}

			// prettier-ignore
			for { } staticcall(gasStipend, currency, add(ptr, 0x20), mload(ptr), 0x00, 0x20) { } {
				let m := mload(0x40) // Grab the free memory pointer.
				let s := add(0x20, m) // Start of the string's bytes in memory.
				// Attempt to `abi.decode` if the returndatasize is greater or equal to 64.
				if iszero(lt(returndatasize(), 0x40)) {
					let o := mload(0x00) // Load the string's offset in the returndata.
					// If the string's offset is within bounds.
					if iszero(gt(o, sub(returndatasize(), 0x20))) {
						returndatacopy(m, o, 0x20) // Copy the string's length.
						// If the full string's end is within bounds.
						// Note: If the full string doesn't fit, the `abi.decode` must be aborted
						// for compliance purposes, regardless if the truncated string can fit.
						if iszero(gt(mload(m), sub(returndatasize(), add(o, 0x20)))) {
							let n := min(mload(m), limit) // Truncate if needed.
							mstore(m, n) // Overwrite the length.
							returndatacopy(s, add(o, 0x20), n) // Copy the string's bytes.
							mstore(add(s, n), 0x00) // Zeroize the slot after the string.
							mstore(0x40, add(0x20, add(s, n))) // Allocate memory for the string.
							result := m
							break
						}
					}
				}
				// Try interpreting as a null-terminated string.
				let n := min(returndatasize(), limit) // Truncate if needed.
				returndatacopy(s, 0x00, n) // Copy the string's bytes.
				mstore8(add(s, n), 0x00) // Place a '\0' at the end.
				let i := s // Pointer to the next byte to scan.
				for { } byte(0x00, mload(i)) { i := add(i, 0x01) } { } // Scan for '\0'.
				mstore(m, sub(i, s)) // Store the string's length.
				mstore(i, 0x00) // Zeroize the slot after the string.
				mstore(0x40, add(0x20, i)) // Allocate memory for the string.
				result := m
				break
			}
		}
	}

	function _uint(Currency currency, bytes32 ptr, uint256 gasStipend) private view returns (uint256 result) {
		assembly ("memory-safe") {
			// prettier-ignore
			result := mul(
				mload(0x20),
				and(gt(returndatasize(), 0x1f), staticcall(gasStipend, currency, add(ptr, 0x20), mload(ptr), 0x20, 0x20))
			)
		}
	}

	function _ptr(uint256 s) private pure returns (bytes32 result) {
		assembly ("memory-safe") {
			mstore(0x04, s)
			mstore(result, 0x04)
		}
	}

	function _ptr(bytes memory data) private pure returns (bytes32 result) {
		assembly ("memory-safe") {
			result := data
		}
	}
}
