// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType} from "src/types/ModuleType.sol";

/// @title RegistryAdapter
/// @notice Provides an interface for interacting with an ERC-7484 compliant registry.
abstract contract RegistryAdapter {
	/// @notice Emitted when a new ERC-7484 registry is successfully configured
	event RegistryConfigured(address indexed registry);

	/// @dev keccak256("RegistryConfigured(address)")
	bytes32 private constant REGISTRY_CONFIGURED_TOPIC =
		0x7d1c97842846d37d5ecd1884bd61723b85333bfbc4e3daa46882adaf1876afd2;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.vortex.storage.registry")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant REGISTRY_STORAGE_SLOT = 0x1a72bca8c19a5ea6f4c84f32c9ea9486de8a7c32689a31ace7fab938dfd59100;

	/// @notice Restricts execution to modules that satisfy the attestation requirements from the configured ERC-7484 registry
	modifier withRegistry(address module, ModuleType moduleTypeId) {
		_checkRegistry(module, moduleTypeId);
		_;
	}

	function _getRegistry() internal view virtual returns (address registry) {
		assembly ("memory-safe") {
			registry := sload(REGISTRY_STORAGE_SLOT)
		}
	}

	function _configureRegistry(address registry, address[] calldata attesters, uint8 threshold) internal virtual {
		assembly ("memory-safe") {
			registry := shr(0x60, shl(0x60, registry))

			sstore(REGISTRY_STORAGE_SLOT, registry)

			log2(codesize(), 0x00, REGISTRY_CONFIGURED_TOPIC, registry)

			if iszero(iszero(registry)) {
				let ptr := mload(0x40)

				mstore(ptr, 0xf05c04e100000000000000000000000000000000000000000000000000000000) // trustAttesters(uint8,address[])
				mstore(add(ptr, 0x04), threshold)
				mstore(add(ptr, 0x24), 0x40)
				mstore(add(ptr, 0x44), attesters.length)
				calldatacopy(add(ptr, 0x64), attesters.offset, shl(0x05, attesters.length))

				if iszero(call(gas(), registry, 0x00, ptr, add(shl(0x05, attesters.length), 0x64), codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function _checkRegistry(address module, ModuleType moduleTypeId) internal view virtual {
		assembly ("memory-safe") {
			let registry := sload(REGISTRY_STORAGE_SLOT)

			if iszero(iszero(registry)) {
				let ptr := mload(0x40)

				mstore(ptr, 0x96fb721700000000000000000000000000000000000000000000000000000000) // check(address,uint256)
				mstore(add(ptr, 0x04), shr(0x60, shl(0x60, module)))
				mstore(add(ptr, 0x24), moduleTypeId)

				if iszero(staticcall(gas(), registry, ptr, 0x44, codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}
}
