// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {IAccountFactory} from "src/interfaces/factories/IAccountFactory.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";

/// @title MetaFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract MetaFactory is IMetaFactory, StakingAdapter {
	/// @dev keccak256("FactoryAuthorized(address)")
	bytes32 private constant FACTORY_AUTHORIZED_TOPIC =
		0x2fa23115f2b369fc34eda97ccf6bc2fab82882719f0547f3e45a9a400086aeae;

	/// @dev keccak256("FactoryRevoked(address)")
	bytes32 private constant FACTORY_REVOKED_TOPIC = 0xd25dd45a1811dc9170ab90c454ef2024f3086a79da5279a8d42f39bdda8f36d1;

	/// @dev keccak256(abi.encode(uint256(keccak256("MetaFactory.storage.factories")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant FACTORIES_STORAGE_SLOT =
		0x1a48f019328e86bb79110a2476eaf4eac06aa7bb49ce27281494e65ed2064800;

	constructor(address initialOwner) StakingAdapter(initialOwner) {}

	function createAccount(bytes calldata data) external payable returns (address payable account) {
		assembly ("memory-safe") {
			// minimum data length = 20 (factory address) + 4 (function selector) + 32 (salt)
			if lt(data.length, 0x38) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let factory := shr(0x60, calldataload(data.offset))
			data.offset := add(data.offset, 0x14)
			data.length := sub(data.length, 0x14)

			mstore(0x00, factory)
			mstore(0x20, FACTORIES_STORAGE_SLOT)

			if iszero(sload(keccak256(0x00, 0x40))) {
				mstore(0x00, 0x644c0c49) // FactoryNotAuthorized(address)
				mstore(0x20, factory)
				revert(0x1c, 0x24)
			}

			let ptr := mload(0x40)
			calldatacopy(ptr, data.offset, data.length)

			if iszero(call(gas(), factory, callvalue(), ptr, data.length, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			account := mload(0x00)
		}
	}

	function computeAddress(address factory, bytes32 salt) external view returns (address payable account) {
		return computeAddress(factory, IAccountFactory(factory).ACCOUNT_IMPLEMENTATION(), salt);
	}

	function computeAddress(
		address factory,
		address implementation,
		bytes32 salt
	) public pure virtual returns (address payable account) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
			mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
			mstore(0x20, 0x6009)
			mstore(0x1e, implementation)
			mstore(0x0a, 0x603d3d8160223d3973)

			mstore(add(ptr, 0x35), keccak256(0x21, 0x5f))
			mstore(ptr, shl(0x58, factory))
			mstore8(ptr, 0xff)
			mstore(add(ptr, 0x15), salt)

			account := keccak256(ptr, 0x55)

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}

	function authorize(address factory) external onlyOwner {
		assembly ("memory-safe") {
			factory := shr(0x60, shl(0x60, factory))

			if iszero(extcodesize(factory)) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, FACTORIES_STORAGE_SLOT)

			sstore(keccak256(0x00, 0x40), 0x01)
			log2(0x00, 0x00, FACTORY_AUTHORIZED_TOPIC, factory)
		}
	}

	function revoke(address factory) external onlyOwner {
		assembly ("memory-safe") {
			factory := shr(0x60, shl(0x60, factory))

			if iszero(extcodesize(factory)) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, FACTORIES_STORAGE_SLOT)

			sstore(keccak256(0x00, 0x40), 0x00)
			log2(0x00, 0x00, FACTORY_REVOKED_TOPIC, factory)
		}
	}

	function isAuthorized(address factory) external view returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, factory)))
			mstore(0x20, FACTORIES_STORAGE_SLOT)
			result := sload(keccak256(0x00, 0x40))
		}
	}
}
