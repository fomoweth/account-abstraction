// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type ResolverUID is bytes32;
type SchemaUID is bytes32;

using {eqResolverUID as ==, neqResolverUID as !=} for ResolverUID global;
using {eqSchemaUID as ==, neqSchemaUID as !=} for SchemaUID global;

function eqResolverUID(ResolverUID x, ResolverUID y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqResolverUID(ResolverUID x, ResolverUID y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqSchemaUID(SchemaUID x, SchemaUID y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqSchemaUID(SchemaUID x, SchemaUID y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title UIDLib
/// @notice Provides functions to encode UID types

library UIDLib {
	function getResolverUID(address sender, address resolver) internal pure returns (ResolverUID) {
		return ResolverUID.wrap(keccak256(abi.encodePacked(sender, resolver)));
	}

	function getSchemaUID(address sender, address validator, string memory schema) internal pure returns (SchemaUID) {
		return SchemaUID.wrap(keccak256(abi.encodePacked(sender, schema, address(validator))));
	}
}
