// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AssociatedArrayLib
/// @dev Implementation from https://github.com/erc7579/enumerablemap/blob/main/src/AssociatedArrayLib.sol
library AssociatedArrayLib {
	struct Array {
		uint256 _spacer;
	}

	function _slot(Array storage s, address account) private pure returns (bytes32 slot) {
		assembly ("memory-safe") {
			mstore(0x00, account)
			mstore(0x20, s.slot)
			slot := keccak256(0x00, 0x40)
		}
	}

	function _length(Array storage s, address account) private view returns (uint256 len) {
		bytes32 slot = _slot(s, account);
		assembly ("memory-safe") {
			len := sload(slot)
		}
	}

	function _get(bytes32 slot, uint256 index) private view returns (bytes32 value) {
		assembly ("memory-safe") {
			if iszero(lt(index, sload(slot))) {
				mstore(0x00, 0x8277484f) // AssociatedArray_OutOfBounds(uint256)
				mstore(0x20, index)
				revert(0x1c, 0x24)
			}

			value := sload(add(slot, add(index, 0x01)))
		}
	}

	function _get(Array storage s, address account, uint256 index) private view returns (bytes32 value) {
		return _get(_slot(s, account), index);
	}

	function _getAll(Array storage s, address account) private view returns (bytes32[] memory values) {
		bytes32 slot = _slot(s, account);
		uint256 len;
		assembly ("memory-safe") {
			len := sload(slot)
		}

		unchecked {
			values = new bytes32[](len);
			for (uint256 i; i < len; ++i) {
				values[i] = _get(slot, i);
			}
		}
	}

	function _contains(Array storage s, address account, bytes32 value) private view returns (bool) {
		bytes32 slot = _slot(s, account);
		uint256 len;
		assembly ("memory-safe") {
			len := sload(slot)
		}

		unchecked {
			for (uint256 i; i < len; ++i) {
				if (_get(slot, i) == value) return true;
			}
		}

		return false;
	}

	function _set(bytes32 slot, uint256 index, bytes32 value) private {
		assembly ("memory-safe") {
			if iszero(lt(index, sload(slot))) {
				mstore(0x00, 0x8277484f) // AssociatedArray_OutOfBounds(uint256)
				mstore(0x20, index)
				revert(0x1c, 0x24)
			}

			sstore(add(slot, add(index, 0x01)), value)
		}
	}

	function _set(Array storage s, address account, uint256 index, bytes32 value) private {
		_set(_slot(s, account), index, value);
	}

	function _push(Array storage s, address account, bytes32 value) private {
		bytes32 slot = _slot(s, account);
		assembly ("memory-safe") {
			let index := sload(slot)
			if gt(index, 127) {
				mstore(0x00, 0x8277484f) // AssociatedArray_OutOfBounds(uint256)
				mstore(0x20, index)
				revert(0x1c, 0x24)
			}

			sstore(add(slot, add(index, 0x01)), value)
			sstore(slot, add(index, 0x01))
		}
	}

	function _pop(Array storage s, address account) private {
		bytes32 slot = _slot(s, account);
		uint256 len;
		assembly ("memory-safe") {
			len := sload(slot)
		}

		if (len == 0) return;

		_set(slot, len - 1, 0);
		assembly ("memory-safe") {
			sstore(slot, sub(len, 0x01))
		}
	}

	function _remove(Array storage s, address account, uint256 index) private {
		bytes32 slot = _slot(s, account);
		uint256 len;
		assembly ("memory-safe") {
			len := sload(slot)
			if iszero(lt(index, len)) {
				mstore(0x00, 0x8277484f) // AssociatedArray_OutOfBounds(uint256)
				mstore(0x20, index)
				revert(0x1c, 0x24)
			}
		}

		_set(slot, index, _get(s, account, len - 1));
		assembly ("memory-safe") {
			sstore(add(slot, len), 0x00)
			sstore(slot, sub(len, 0x01))
		}
	}

	struct Bytes32Array {
		Array _inner;
	}

	function length(Bytes32Array storage s, address account) internal view returns (uint256) {
		return _length(s._inner, account);
	}

	function get(Bytes32Array storage s, address account, uint256 index) internal view returns (bytes32) {
		return _get(s._inner, account, index);
	}

	function getAll(Bytes32Array storage s, address account) internal view returns (bytes32[] memory) {
		return _getAll(s._inner, account);
	}

	function contains(Bytes32Array storage s, address account, bytes32 value) internal view returns (bool) {
		return _contains(s._inner, account, value);
	}

	function add(Bytes32Array storage s, address account, bytes32 value) internal {
		if (!_contains(s._inner, account, value)) {
			_push(s._inner, account, value);
		}
	}

	function set(Bytes32Array storage s, address account, uint256 index, bytes32 value) internal {
		_set(s._inner, account, index, value);
	}

	function push(Bytes32Array storage s, address account, bytes32 value) internal {
		_push(s._inner, account, value);
	}

	function pop(Bytes32Array storage s, address account) internal {
		_pop(s._inner, account);
	}

	function remove(Bytes32Array storage s, address account, uint256 index) internal {
		_remove(s._inner, account, index);
	}

	struct AddressArray {
		Array _inner;
	}

	function length(AddressArray storage s, address account) internal view returns (uint256) {
		return _length(s._inner, account);
	}

	function get(AddressArray storage s, address account, uint256 index) internal view returns (address) {
		return address(uint160(uint256(_get(s._inner, account, index))));
	}

	function getAll(AddressArray storage s, address account) internal view returns (address[] memory result) {
		bytes32[] memory store = _getAll(s._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	function contains(AddressArray storage s, address account, address value) internal view returns (bool) {
		return _contains(s._inner, account, bytes32(uint256(uint160(value))));
	}

	function add(AddressArray storage s, address account, address value) internal {
		if (!_contains(s._inner, account, bytes32(uint256(uint160(value))))) {
			_push(s._inner, account, bytes32(uint256(uint160(value))));
		}
	}

	function set(AddressArray storage s, address account, uint256 index, address value) internal {
		_set(s._inner, account, index, bytes32(uint256(uint160(value))));
	}

	function push(AddressArray storage s, address account, address value) internal {
		_push(s._inner, account, bytes32(uint256(uint160(value))));
	}

	function pop(AddressArray storage s, address account) internal {
		_pop(s._inner, account);
	}

	function remove(AddressArray storage s, address account, uint256 index) internal {
		_remove(s._inner, account, index);
	}

	struct UintArray {
		Array _inner;
	}

	function length(UintArray storage s, address account) internal view returns (uint256) {
		return _length(s._inner, account);
	}

	function get(UintArray storage s, address account, uint256 index) internal view returns (uint256) {
		return uint256(_get(s._inner, account, index));
	}

	function getAll(UintArray storage s, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = _getAll(s._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	function contains(UintArray storage s, address account, uint256 value) internal view returns (bool) {
		return _contains(s._inner, account, bytes32(value));
	}

	function add(UintArray storage s, address account, uint256 value) internal {
		if (!_contains(s._inner, account, bytes32(value))) {
			_push(s._inner, account, bytes32(value));
		}
	}

	function set(UintArray storage s, address account, uint256 index, uint256 value) internal {
		_set(s._inner, account, index, bytes32(value));
	}

	function push(UintArray storage s, address account, uint256 value) internal {
		_push(s._inner, account, bytes32(value));
	}

	function pop(UintArray storage s, address account) internal {
		_pop(s._inner, account);
	}

	function remove(UintArray storage s, address account, uint256 index) internal {
		_remove(s._inner, account, index);
	}
}
