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

	/// @dev keccak256("ModuleDeployed(address,bytes32)")
	bytes32 private constant MODULE_DEPLOYED_TOPIC = 0x4f980749b81a25271e0bfdc77dd2910421a2226fe562a239470c55be0903c6cd;

	/// @dev keccak256(abi.encode(uint256(keccak256("MetaFactory.storage.factories")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant FACTORIES_STORAGE_SLOT =
		0x1a48f019328e86bb79110a2476eaf4eac06aa7bb49ce27281494e65ed2064800;

	/// @dev keccak256(abi.encode(uint256(keccak256("MetaFactory.transient-storage.context")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant CONTEXT_TRANSIENT_SLOT =
		0x3a4e39694004bdaad4ab219aa0f879af381de0c1cfe536e45dab22dc6061c000;

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
			mstore(0x20, FACTORIES_STORAGE_SLOT)

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
		return IAccountFactory(factory).computeAddress(salt);
	}

	function deployModule(
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module) {
		bytes memory initCode = abi.encodePacked(bytecode, params);

		assembly ("memory-safe") {
			if gt(params.length, 0xffffffff) {
				mstore(0x00, 0x23ba9bc3) // ExceededMaxLength()
				revert(0x1c, 0x04)
			}

			if iszero(iszero(params.length)) {
				tstore(CONTEXT_TRANSIENT_SLOT, calldataload(sub(params.offset, 0x04)))

				if gt(params.length, sub(0x20, 0x04)) {
					mstore(0x00, CONTEXT_TRANSIENT_SLOT)
					let slot := keccak256(0x00, 0x20)
					let pos := add(params.offset, sub(0x20, 0x04))
					let guard := sub(add(params.offset, params.length), 0x01)

					// prettier-ignore
					for { } 0x01 { } {
						tstore(slot, calldataload(pos))
						pos := add(pos, 0x20)
						if gt(pos, guard) { break }
						slot := add(slot, 0x01)
					}
				}
			}

			module := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(module) {
				mstore(0x00, 0x036d42bd) // ModuleDeploymentFailed()
				revert(0x1c, 0x04)
			}

			log3(0x00, 0x00, MODULE_DEPLOYED_TOPIC, module, salt)

			tstore(CONTEXT_TRANSIENT_SLOT, 0x00)
		}
	}

	function parameters() external view returns (bytes memory context) {
		assembly ("memory-safe") {
			context := mload(0x40)
			mstore(context, 0x00)
			mstore(add(context, sub(0x20, 0x04)), tload(CONTEXT_TRANSIENT_SLOT))

			let length := mload(context)
			let offset := add(context, 0x20)
			mstore(0x40, add(offset, length))

			if gt(length, sub(0x20, 0x04)) {
				mstore(0x00, CONTEXT_TRANSIENT_SLOT)
				let slot := keccak256(0x00, 0x20)
				let pos := add(offset, sub(0x20, 0x04))
				let guard := add(offset, length)

				// prettier-ignore
				for { } 0x01 { } {
					mstore(pos, tload(slot))
					pos := add(pos, 0x20)
					if gt(pos, guard) { break }
					slot := add(slot, 0x01)
				}

				mstore(guard, 0x00)
			}
		}
	}

	function computeAddress(bytes32 salt, bytes calldata initCode) external view returns (address instance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			calldatacopy(add(ptr, 0x40), initCode.offset, initCode.length)
			mstore(add(ptr, 0x40), keccak256(add(ptr, 0x40), initCode.length))
			mstore(add(ptr, 0x20), salt)
			mstore(ptr, address())
			mstore8(add(ptr, 0x0b), 0xff)

			instance := shr(0x60, shl(0x60, keccak256(add(ptr, 0x0b), 0x55)))
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
			mstore(0x20, FACTORIES_STORAGE_SLOT)

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
