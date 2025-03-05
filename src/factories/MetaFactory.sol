// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";

/// @title MetaFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract MetaFactory is IMetaFactory, StakingAdapter {
	/// @dev keccak256("Authorized(address)")
	bytes32 private constant AUTHORIZED_TOPIC = 0xdc84e3a4c83602050e3865df792a4e6800211a79ac60db94e703a820ce892924;

	/// @dev keccak256("Revoked(address)")
	bytes32 private constant REVOKED_TOPIC = 0xb6fa8b8bd5eab60f292eca876e3ef90722275b785309d84b1de113ce0b8c4e74;

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

	function isAuthorized(address factory) public view virtual returns (bool result) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, factory)))
			mstore(0x20, FACTORIES_STORAGE_SLOT)
			result := sload(keccak256(0x00, 0x40))
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
			log2(0x00, 0x00, AUTHORIZED_TOPIC, factory)
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
			log2(0x00, 0x00, REVOKED_TOPIC, factory)
		}
	}
}
