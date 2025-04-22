// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {ModuleType} from "src/types/DataTypes.sol";

/// @title ERC7201
/// @notice Manages isolated storage spaces for smart account in compliance with ERC-7201 standard
contract ERC7201 {
	struct AccountStorage {
		address rootValidator;
		EnumerableSetLib.AddressSet validators;
		EnumerableSetLib.AddressSet executors;
		EnumerableSetLib.AddressSet hooks;
		mapping(ModuleType moduleTypeId => address hook) preValidationHooks;
	}

	/// @custom:storage-location erc7201:eip7579.vortex.storage.modules
	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.vortex.storage.modules")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant STORAGE_NAMESPACE = 0xffb1db744ac0caf2c7f81a63c0858e72cff909d0c940f6d0d5009607061ef100;

	function _getAccountStorage() internal pure virtual returns (AccountStorage storage $) {
		assembly ("memory-safe") {
			$.slot := STORAGE_NAMESPACE
		}
	}
}
