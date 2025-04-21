// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet4337} from "./EnumerableSet4337.sol";

/// @title EnumerableMap
/// @dev Implementation from https://github.com/erc7579/enumerablemap/blob/main/src/EnumerableMap4337.sol
library EnumerableMap4337 {
	using EnumerableSet4337 for EnumerableSet4337.Bytes32Set;

	// To implement this library for multiple types with as little code repetition as possible, we write it in
	// terms of a generic Map type with bytes32 keys and values. The Map implementation uses private functions,
	// and user-facing implementations such as `UintToAddressMap` are just wrappers around the underlying Map.
	// This means that we can only create new EnumerableMaps for types that fit in bytes32.

	/**
	 * @dev Query for a nonexistent map key.
	 */
	error EnumerableMapNonexistentKey(bytes32 key);

	struct Bytes32ToBytes32Map {
		// Storage of keys
		EnumerableSet4337.Bytes32Set _keys;
		mapping(bytes32 key => mapping(address account => bytes32)) _values;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function set(Bytes32ToBytes32Map storage map, address account, bytes32 key, bytes32 value) internal returns (bool) {
		map._values[key][account] = value;
		return map._keys.add(account, key);
	}

	/**
	 * @dev Removes a key-value pair from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function remove(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal returns (bool) {
		delete map._values[key][account];
		return map._keys.remove(account, key);
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function contains(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal view returns (bool) {
		return map._keys.contains(account, key);
	}

	/**
	 * @dev Returns the number of key-value pairs in the map. O(1).
	 */
	function length(Bytes32ToBytes32Map storage map, address account) internal view returns (uint256) {
		return map._keys.length(account);
	}

	/**
	 * @dev Returns the key-value pair stored at position `index` in the map. O(1).
	 *
	 * Note that there are no guarantees on the ordering of entries inside the
	 * array, and it may change when more entries are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function at(
		Bytes32ToBytes32Map storage map,
		address account,
		uint256 index
	) internal view returns (bytes32, bytes32) {
		bytes32 key = map._keys.at(account, index);
		return (key, map._values[key][account]);
	}

	/**
	 * @dev Tries to returns the value associated with `key`. O(1).
	 * Does not revert if `key` is not in the map.
	 */
	function tryGet(
		Bytes32ToBytes32Map storage map,
		address account,
		bytes32 key
	) internal view returns (bool, bytes32) {
		bytes32 value = map._values[key][account];
		if (value == bytes32(0)) {
			return (contains(map, account, key), bytes32(0));
		} else {
			return (true, value);
		}
	}

	/**
	 * @dev Returns the value associated with `key`. O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function get(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal view returns (bytes32) {
		bytes32 value = map._values[key][account];
		if (value == 0 && !contains(map, account, key)) revert EnumerableMapNonexistentKey(key);

		return value;
	}

	/**
	 * @dev Return the an array containing all the keys
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 */
	function keys(Bytes32ToBytes32Map storage map, address account) internal view returns (bytes32[] memory) {
		return map._keys.values(account);
	}

	struct UintToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function set(UintToUintMap storage map, address account, uint256 key, uint256 value) internal returns (bool) {
		return set(map._inner, account, bytes32(key), bytes32(value));
	}

	/**
	 * @dev Removes a value from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function remove(UintToUintMap storage map, address account, uint256 key) internal returns (bool) {
		return remove(map._inner, account, bytes32(key));
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function contains(UintToUintMap storage map, address account, uint256 key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(key));
	}

	/**
	 * @dev Returns the number of elements in the map. O(1).
	 */
	function length(UintToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	/**
	 * @dev Returns the element stored at position `index` in the map. O(1).
	 * Note that there are no guarantees on the ordering of values inside the
	 * array, and it may change when more values are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function at(UintToUintMap storage map, address account, uint256 index) internal view returns (uint256, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (uint256(key), uint256(value));
	}

	/**
	 * @dev Tries to returns the value associated with `key`. O(1).
	 * Does not revert if `key` is not in the map.
	 */
	function tryGet(UintToUintMap storage map, address account, uint256 key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(key));
		return (success, uint256(value));
	}

	/**
	 * @dev Returns the value associated with `key`. O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function get(UintToUintMap storage map, address account, uint256 key) internal view returns (uint256) {
		return uint256(get(map._inner, account, bytes32(key)));
	}

	/**
	 * @dev Return the an array containing all the keys
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 */
	function keys(UintToUintMap storage map, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct UintToAddressMap {
		Bytes32ToBytes32Map _inner;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function set(UintToAddressMap storage map, address account, uint256 key, address value) internal returns (bool) {
		return set(map._inner, account, bytes32(key), bytes32(uint256(uint160(value))));
	}

	/**
	 * @dev Removes a value from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function remove(UintToAddressMap storage map, address account, uint256 key) internal returns (bool) {
		return remove(map._inner, account, bytes32(key));
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function contains(UintToAddressMap storage map, address account, uint256 key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(key));
	}

	/**
	 * @dev Returns the number of elements in the map. O(1).
	 */
	function length(UintToAddressMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	/**
	 * @dev Returns the element stored at position `index` in the map. O(1).
	 * Note that there are no guarantees on the ordering of values inside the
	 * array, and it may change when more values are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function at(UintToAddressMap storage map, address account, uint256 index) internal view returns (uint256, address) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (uint256(key), address(uint160(uint256(value))));
	}

	/**
	 * @dev Tries to returns the value associated with `key`. O(1).
	 * Does not revert if `key` is not in the map.
	 */
	function tryGet(UintToAddressMap storage map, address account, uint256 key) internal view returns (bool, address) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(key));
		return (success, address(uint160(uint256(value))));
	}

	/**
	 * @dev Returns the value associated with `key`. O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function get(UintToAddressMap storage map, address account, uint256 key) internal view returns (address) {
		return address(uint160(uint256(get(map._inner, account, bytes32(key)))));
	}

	/**
	 * @dev Return the an array containing all the keys
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 */
	function keys(UintToAddressMap storage map, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct AddressToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function set(AddressToUintMap storage map, address account, address key, uint256 value) internal returns (bool) {
		return set(map._inner, account, bytes32(uint256(uint160(key))), bytes32(value));
	}

	/**
	 * @dev Removes a value from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function remove(AddressToUintMap storage map, address account, address key) internal returns (bool) {
		return remove(map._inner, account, bytes32(uint256(uint160(key))));
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function contains(AddressToUintMap storage map, address account, address key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(uint256(uint160(key))));
	}

	/**
	 * @dev Returns the number of elements in the map. O(1).
	 */
	function length(AddressToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	/**
	 * @dev Returns the element stored at position `index` in the map. O(1).
	 * Note that there are no guarantees on the ordering of values inside the
	 * array, and it may change when more values are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function at(AddressToUintMap storage map, address account, uint256 index) internal view returns (address, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (address(uint160(uint256(key))), uint256(value));
	}

	/**
	 * @dev Tries to returns the value associated with `key`. O(1).
	 * Does not revert if `key` is not in the map.
	 */
	function tryGet(AddressToUintMap storage map, address account, address key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(uint256(uint160(key))));
		return (success, uint256(value));
	}

	/**
	 * @dev Returns the value associated with `key`. O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function get(AddressToUintMap storage map, address account, address key) internal view returns (uint256) {
		return uint256(get(map._inner, account, bytes32(uint256(uint160(key)))));
	}

	/**
	 * @dev Return the an array containing all the keys
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 */
	function keys(AddressToUintMap storage map, address account) internal view returns (address[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct Bytes32ToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function set(Bytes32ToUintMap storage map, address account, bytes32 key, uint256 value) internal returns (bool) {
		return set(map._inner, account, key, bytes32(value));
	}

	/**
	 * @dev Removes a value from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function remove(Bytes32ToUintMap storage map, address account, bytes32 key) internal returns (bool) {
		return remove(map._inner, account, key);
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function contains(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (bool) {
		return contains(map._inner, account, key);
	}

	/**
	 * @dev Returns the number of elements in the map. O(1).
	 */
	function length(Bytes32ToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	/**
	 * @dev Returns the element stored at position `index` in the map. O(1).
	 * Note that there are no guarantees on the ordering of values inside the
	 * array, and it may change when more values are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function at(Bytes32ToUintMap storage map, address account, uint256 index) internal view returns (bytes32, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (key, uint256(value));
	}

	/**
	 * @dev Tries to returns the value associated with `key`. O(1).
	 * Does not revert if `key` is not in the map.
	 */
	function tryGet(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, key);
		return (success, uint256(value));
	}

	/**
	 * @dev Returns the value associated with `key`. O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function get(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (uint256) {
		return uint256(get(map._inner, account, key));
	}

	/**
	 * @dev Return the an array containing all the keys
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 */
	function keys(Bytes32ToUintMap storage map, address account) internal view returns (bytes32[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}
}
