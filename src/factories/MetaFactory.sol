// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";

/// @title MetaFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract MetaFactory is IMetaFactory, StakingAdapter {
	/// @dev keccak256("WhitelistSet(address,bool)")
	bytes32 private constant WHITELIST_SET_TOPIC = 0x0aa5ec5ffdc7f6f9c4d0dded489d7450297155cb2f71cb771e02427f7dff4f51;

	/// @dev keccak256(abi.encode(uint256(keccak256("MetaFactory.storage.whitelists")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant WHITELISTS_SLOT = 0x6ba078324212c930c90a4ce06d05625f4e98f1d7f525257a5660053cd6e8a200;

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
			mstore(0x20, WHITELISTS_SLOT)

			if iszero(sload(keccak256(0x00, 0x40))) {
				mstore(0x00, 0xbd3ce38c) // FactoryNotWhitelisted(address)
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

	function setWhitelist(address factory, bool approval) external onlyOwner {
		assembly ("memory-safe") {
			factory := shr(0x60, shl(0x60, factory))
			if iszero(extcodesize(factory)) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, WHITELISTS_SLOT)

			sstore(keccak256(0x00, 0x40), approval)
			log3(0x00, 0x00, WHITELIST_SET_TOPIC, factory, approval)
		}
	}

	function isWhitelisted(address factory) external view returns (bool flag) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, factory)))
			mstore(0x20, WHITELISTS_SLOT)

			flag := sload(keccak256(0x00, 0x40))
		}
	}
}
