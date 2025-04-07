// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";

/// @title MetaFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract MetaFactory is IMetaFactory, StakingAdapter {
	/// @dev keccak256("FactoryAuthorized(address)")
	bytes32 private constant FACTORY_AUTHORIZED_TOPIC =
		0x2fa23115f2b369fc34eda97ccf6bc2fab82882719f0547f3e45a9a400086aeae;

	/// @dev keccak256("FactoryRevoked(address)")
	bytes32 private constant FACTORY_REVOKED_TOPIC = 0xd25dd45a1811dc9170ab90c454ef2024f3086a79da5279a8d42f39bdda8f36d1;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.MetaFactory.authority")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant AUTHORITY_STORAGE_SLOT =
		0xed9afa57181e1288cca2500b59ae100696098cf8a47aa6472021d8957422f100;

	constructor(address initialOwner) StakingAdapter(initialOwner) {}

	function createAccount(bytes calldata params) external payable returns (address payable account) {
		assembly ("memory-safe") {
			if lt(params.length, 0x38) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let factory := shr(0x60, calldataload(params.offset))
			params.offset := add(params.offset, 0x14)
			params.length := sub(params.length, 0x14)

			mstore(0x00, factory)
			mstore(0x20, AUTHORITY_STORAGE_SLOT)

			if iszero(sload(keccak256(0x00, 0x40))) {
				mstore(0x00, 0x644c0c49) // FactoryNotAuthorized(address)
				mstore(0x20, factory)
				revert(0x1c, 0x24)
			}

			let ptr := mload(0x40)
			calldatacopy(ptr, params.offset, params.length)

			if iszero(call(gas(), factory, callvalue(), ptr, params.length, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			account := mload(0x00)
		}
	}

	function computeAddress(address factory, bytes32 salt) external view returns (address payable account) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x7fde56da00000000000000000000000000000000000000000000000000000000) // computeAddress(bytes32)
			mstore(add(ptr, 0x04), salt)

			if iszero(staticcall(gas(), factory, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			account := mload(0x00)
		}
	}

	function authorize(address factory) external onlyOwner {
		assembly ("memory-safe") {
			factory := shr(0x60, shl(0x60, factory))
			if iszero(factory) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, AUTHORITY_STORAGE_SLOT)

			sstore(keccak256(0x00, 0x40), 0x01)
			log2(0x00, 0x00, FACTORY_AUTHORIZED_TOPIC, factory)
		}
	}

	function revoke(address factory) external onlyOwner {
		assembly ("memory-safe") {
			factory := shr(0x60, shl(0x60, factory))
			if iszero(factory) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, AUTHORITY_STORAGE_SLOT)

			sstore(keccak256(0x00, 0x40), 0x00)
			log2(0x00, 0x00, FACTORY_REVOKED_TOPIC, factory)
		}
	}

	function isAuthorized(address factory) external view returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, factory)))
			mstore(0x20, AUTHORITY_STORAGE_SLOT)
			result := sload(keccak256(0x00, 0x40))
		}
	}
}
