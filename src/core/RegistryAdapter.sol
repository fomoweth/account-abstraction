// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title RegistryAdapter
/// @notice Provides an interface for interacting with an ERC-7484 compliant registry

abstract contract RegistryAdapter {
	/// @dev keccak256(bytes("RegistryConfigured(address)"))
	bytes32 private constant REGISTRY_CONFIGURED_TOPIC =
		0x7d1c97842846d37d5ecd1884bd61723b85333bfbc4e3daa46882adaf1876afd2;

	/// @dev keccak256(abi.encode(uint256(keccak256("RegistryAdapter.storage.registry.slot")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant REGISTRY_SLOT = 0x67e0273ac2b255238360b830e41038fb59396476606ad3224640c0859a888900;

	modifier withRegistry(address module, uint256 moduleTypeId) {
		_checkRegistry(module, moduleTypeId);
		_;
	}

	function _registry() internal view virtual returns (address registry) {
		assembly ("memory-safe") {
			registry := sload(REGISTRY_SLOT)
		}
	}

	function _configureRegistry(address registry, address[] calldata attesters, uint8 threshold) internal virtual {
		assembly ("memory-safe") {
			registry := shr(0x60, shl(0x60, registry))
			sstore(REGISTRY_SLOT, registry)
			log2(codesize(), 0x00, REGISTRY_CONFIGURED_TOPIC, registry)

			if registry {
				let ptr := mload(0x40)

				mstore(ptr, 0xf05c04e100000000000000000000000000000000000000000000000000000000) // trustAttesters(uint8,address[])
				mstore(add(ptr, 0x04), threshold)
				mstore(add(ptr, 0x24), 0x40)
				mstore(add(ptr, 0x44), attesters.length)
				calldatacopy(add(ptr, 0x64), attesters.offset, shl(0x05, attesters.length))

				if iszero(call(gas(), registry, 0x00, ptr, add(shl(0x05, attesters.length), 0x64), 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function _checkRegistry(address module, uint256 moduleTypeId) internal view virtual {
		assembly ("memory-safe") {
			let registry := sload(REGISTRY_SLOT)
			if registry {
				let ptr := mload(0x40)

				mstore(ptr, 0x96fb721700000000000000000000000000000000000000000000000000000000) // check(address,uint256)
				mstore(add(ptr, 0x04), and(module, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), moduleTypeId)

				if iszero(staticcall(gas(), registry, ptr, 0x44, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}
}
