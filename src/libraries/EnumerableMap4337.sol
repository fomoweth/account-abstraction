// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet4337} from "./EnumerableSet4337.sol";

/// @title EnumerableMap
/// @dev Implementation from https://github.com/erc7579/enumerablemap/blob/main/src/EnumerableMap4337.sol

library EnumerableMap4337 {
	using EnumerableSet4337 for EnumerableSet4337.Bytes32Set;

	error EnumerableMapNonexistentKey(bytes32 key);

	struct Bytes32ToBytes32Map {
		EnumerableSet4337.Bytes32Set _keys;
		mapping(bytes32 key => mapping(address account => bytes32)) _values;
	}

	function set(Bytes32ToBytes32Map storage map, address account, bytes32 key, bytes32 value) internal returns (bool) {
		map._values[key][account] = value;
		return map._keys.add(account, key);
	}

	function remove(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal returns (bool) {
		delete map._values[key][account];
		return map._keys.remove(account, key);
	}

	function contains(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal view returns (bool) {
		return map._keys.contains(account, key);
	}

	function length(Bytes32ToBytes32Map storage map, address account) internal view returns (uint256) {
		return map._keys.length(account);
	}

	function at(
		Bytes32ToBytes32Map storage map,
		address account,
		uint256 index
	) internal view returns (bytes32, bytes32) {
		bytes32 key = map._keys.at(account, index);
		return (key, map._values[key][account]);
	}

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

	function get(Bytes32ToBytes32Map storage map, address account, bytes32 key) internal view returns (bytes32) {
		bytes32 value = map._values[key][account];
		if (value == 0 && !contains(map, account, key)) revert EnumerableMapNonexistentKey(key);

		return value;
	}

	function keys(Bytes32ToBytes32Map storage map, address account) internal view returns (bytes32[] memory) {
		return map._keys.values(account);
	}

	struct UintToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	function set(UintToUintMap storage map, address account, uint256 key, uint256 value) internal returns (bool) {
		return set(map._inner, account, bytes32(key), bytes32(value));
	}

	function remove(UintToUintMap storage map, address account, uint256 key) internal returns (bool) {
		return remove(map._inner, account, bytes32(key));
	}

	function contains(UintToUintMap storage map, address account, uint256 key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(key));
	}

	function length(UintToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	function at(UintToUintMap storage map, address account, uint256 index) internal view returns (uint256, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (uint256(key), uint256(value));
	}

	function tryGet(UintToUintMap storage map, address account, uint256 key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(key));
		return (success, uint256(value));
	}

	function get(UintToUintMap storage map, address account, uint256 key) internal view returns (uint256) {
		return uint256(get(map._inner, account, bytes32(key)));
	}

	function keys(UintToUintMap storage map, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct UintToAddressMap {
		Bytes32ToBytes32Map _inner;
	}

	function set(UintToAddressMap storage map, address account, uint256 key, address value) internal returns (bool) {
		return set(map._inner, account, bytes32(key), bytes32(uint256(uint160(value))));
	}

	function remove(UintToAddressMap storage map, address account, uint256 key) internal returns (bool) {
		return remove(map._inner, account, bytes32(key));
	}

	function contains(UintToAddressMap storage map, address account, uint256 key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(key));
	}

	function length(UintToAddressMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	function at(UintToAddressMap storage map, address account, uint256 index) internal view returns (uint256, address) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (uint256(key), address(uint160(uint256(value))));
	}

	function tryGet(UintToAddressMap storage map, address account, uint256 key) internal view returns (bool, address) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(key));
		return (success, address(uint160(uint256(value))));
	}

	function get(UintToAddressMap storage map, address account, uint256 key) internal view returns (address) {
		return address(uint160(uint256(get(map._inner, account, bytes32(key)))));
	}

	function keys(UintToAddressMap storage map, address account) internal view returns (uint256[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct AddressToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	function set(AddressToUintMap storage map, address account, address key, uint256 value) internal returns (bool) {
		return set(map._inner, account, bytes32(uint256(uint160(key))), bytes32(value));
	}

	function remove(AddressToUintMap storage map, address account, address key) internal returns (bool) {
		return remove(map._inner, account, bytes32(uint256(uint160(key))));
	}

	function contains(AddressToUintMap storage map, address account, address key) internal view returns (bool) {
		return contains(map._inner, account, bytes32(uint256(uint160(key))));
	}

	function length(AddressToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	function at(AddressToUintMap storage map, address account, uint256 index) internal view returns (address, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (address(uint160(uint256(key))), uint256(value));
	}

	function tryGet(AddressToUintMap storage map, address account, address key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, bytes32(uint256(uint160(key))));
		return (success, uint256(value));
	}

	function get(AddressToUintMap storage map, address account, address key) internal view returns (uint256) {
		return uint256(get(map._inner, account, bytes32(uint256(uint160(key)))));
	}

	function keys(AddressToUintMap storage map, address account) internal view returns (address[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}

	struct Bytes32ToUintMap {
		Bytes32ToBytes32Map _inner;
	}

	function set(Bytes32ToUintMap storage map, address account, bytes32 key, uint256 value) internal returns (bool) {
		return set(map._inner, account, key, bytes32(value));
	}

	function remove(Bytes32ToUintMap storage map, address account, bytes32 key) internal returns (bool) {
		return remove(map._inner, account, key);
	}

	function contains(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (bool) {
		return contains(map._inner, account, key);
	}

	function length(Bytes32ToUintMap storage map, address account) internal view returns (uint256) {
		return length(map._inner, account);
	}

	function at(Bytes32ToUintMap storage map, address account, uint256 index) internal view returns (bytes32, uint256) {
		(bytes32 key, bytes32 value) = at(map._inner, account, index);
		return (key, uint256(value));
	}

	function tryGet(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (bool, uint256) {
		(bool success, bytes32 value) = tryGet(map._inner, account, key);
		return (success, uint256(value));
	}

	function get(Bytes32ToUintMap storage map, address account, bytes32 key) internal view returns (uint256) {
		return uint256(get(map._inner, account, key));
	}

	function keys(Bytes32ToUintMap storage map, address account) internal view returns (bytes32[] memory result) {
		bytes32[] memory store = keys(map._inner, account);

		assembly ("memory-safe") {
			result := store
		}
	}
}
