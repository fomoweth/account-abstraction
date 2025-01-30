// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AssociatedArrayLib} from "./AssociatedArrayLib.sol";

/// @title EnumerableSet4337
/// @dev Implementation from https://github.com/erc7579/enumerablemap/blob/main/src/EnumerableSet4337.sol

library EnumerableSet4337 {
	using AssociatedArrayLib for AssociatedArrayLib.Bytes32Array;

	struct Set {
		AssociatedArrayLib.Bytes32Array _values;
		mapping(bytes32 value => mapping(address account => uint256 position)) _positions;
	}

	function _add(Set storage set, address account, bytes32 value) private returns (bool) {
		if (!_contains(set, account, value)) {
			set._values.push(account, value);
			set._positions[value][account] = set._values.length(account);

			return true;
		} else {
			return false;
		}
	}

	function _remove(Set storage set, address account, bytes32 value) private returns (bool) {
		uint256 position = set._positions[value][account];
		if (position != 0) {
			uint256 valueIndex = position - 1;
			uint256 lastIndex = set._values.length(account) - 1;

			if (valueIndex != lastIndex) {
				bytes32 lastValue = set._values.get(account, lastIndex);

				set._values.set(account, valueIndex, lastValue);
				set._positions[lastValue][account] = position;
			}

			set._values.pop(account);
			delete set._positions[value][account];

			return true;
		} else {
			return false;
		}
	}

	function _removeAll(Set storage set, address account) internal {
		unchecked {
			uint256 len = _length(set, account);
			for (uint256 i = 1; i <= len; ++i) {
				bytes32 value = _at(set, account, len - i);
				_remove(set, account, value);
			}
		}
	}

	function _contains(Set storage set, address account, bytes32 value) private view returns (bool) {
		return set._positions[value][account] != 0;
	}

	function _length(Set storage set, address account) private view returns (uint256) {
		return set._values.length(account);
	}

	function _at(Set storage set, address account, uint256 index) private view returns (bytes32) {
		return set._values.get(account, index);
	}

	function _values(Set storage set, address account) private view returns (bytes32[] memory) {
		return set._values.getAll(account);
	}

	struct Bytes32Set {
		Set _inner;
	}

	function add(Bytes32Set storage set, address account, bytes32 value) internal returns (bool) {
		return _add(set._inner, account, value);
	}

	function remove(Bytes32Set storage set, address account, bytes32 value) internal returns (bool) {
		return _remove(set._inner, account, value);
	}

	function removeAll(Bytes32Set storage set, address account) internal {
		return _removeAll(set._inner, account);
	}

	function contains(Bytes32Set storage set, address account, bytes32 value) internal view returns (bool) {
		return _contains(set._inner, account, value);
	}

	function length(Bytes32Set storage set, address account) internal view returns (uint256) {
		return _length(set._inner, account);
	}

	function at(Bytes32Set storage set, address account, uint256 index) internal view returns (bytes32) {
		return _at(set._inner, account, index);
	}

	function values(Bytes32Set storage set, address account) internal view returns (bytes32[] memory result) {
		bytes32[] memory store = _values(set._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct AddressSet {
		Set _inner;
	}

	function add(AddressSet storage set, address account, address value) internal returns (bool) {
		return _add(set._inner, account, bytes32(uint256(uint160(value))));
	}

	function remove(AddressSet storage set, address account, address value) internal returns (bool) {
		return _remove(set._inner, account, bytes32(uint256(uint160(value))));
	}

	function removeAll(AddressSet storage set, address account) internal {
		return _removeAll(set._inner, account);
	}

	function contains(AddressSet storage set, address account, address value) internal view returns (bool) {
		return _contains(set._inner, account, bytes32(uint256(uint160(value))));
	}

	function length(AddressSet storage set, address account) internal view returns (uint256) {
		return _length(set._inner, account);
	}

	function at(AddressSet storage set, address account, uint256 index) internal view returns (address) {
		return address(uint160(uint256(_at(set._inner, account, index))));
	}

	function values(AddressSet storage set, address account) internal view returns (address[] memory result) {
		bytes32[] memory store = _values(set._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct UintSet {
		Set _inner;
	}

	function add(UintSet storage set, address account, uint256 value) internal returns (bool) {
		return _add(set._inner, account, bytes32(value));
	}

	function remove(UintSet storage set, address account, uint256 value) internal returns (bool) {
		return _remove(set._inner, account, bytes32(value));
	}

	function removeAll(UintSet storage set, address account) internal {
		return _removeAll(set._inner, account);
	}

	function contains(UintSet storage set, address account, uint256 value) internal view returns (bool) {
		return _contains(set._inner, account, bytes32(value));
	}

	function length(UintSet storage set, address account) internal view returns (uint256) {
		return _length(set._inner, account);
	}

	function at(UintSet storage set, address account, uint256 index) internal view returns (uint256) {
		return uint256(_at(set._inner, account, index));
	}

	function values(UintSet storage set, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = _values(set._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}
}
