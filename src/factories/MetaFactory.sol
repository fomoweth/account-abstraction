// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {Ownable} from "src/utils/Ownable.sol";

/// @title MetaFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract MetaFactory is IMetaFactory, Ownable {
	/// @dev keccak256(bytes("WhitelistSet(address,bool)"))
	bytes32 private constant WHITELIST_SET_TOPIC = 0x0aa5ec5ffdc7f6f9c4d0dded489d7450297155cb2f71cb771e02427f7dff4f51;

	/// @dev keccak256(abi.encode(uint256(keccak256("MetaFactory.storage.whitelists")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant WHITELISTS_SLOT = 0x6ba078324212c930c90a4ce06d05625f4e98f1d7f525257a5660053cd6e8a200;

	constructor(address initialOwner) {
		_initializeOwner(initialOwner);
	}

	function createAccount(bytes calldata data) external payable returns (address payable account) {
		assembly ("memory-safe") {
			// 20 (factory address) + 4 (function selector)
			if lt(data.length, 0x18) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let factory := shr(0x60, calldataload(data.offset))
			data.offset := add(data.offset, 0x14)
			data.length := sub(data.length, 0x14)

			mstore(0x00, factory)
			mstore(0x20, WHITELISTS_SLOT)

			if iszero(sload(keccak256(0x00, 0x40))) {
				mstore(0x00, 0xbd3ce38c00000000000000000000000000000000000000000000000000000000) // FactoryNotWhitelisted(address)
				mstore(0x04, factory)
				revert(0x00, 0x24)
			}

			let ptr := mload(0x40)

			calldatacopy(ptr, data.offset, data.length)

			if iszero(call(gas(), factory, callvalue(), ptr, data.length, 0x00, 0x20)) {
				mstore(0x00, 0x20188a59) // AccountCreationFailed()
				revert(0x1c, 0x04)
			}

			account := mload(0x00)
		}
	}

	function addStake(address entryPoint, uint32 unstakeDelaySec) external payable onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x0396cb6000000000000000000000000000000000000000000000000000000000) // addStake(uint32)
			mstore(add(ptr, 0x04), and(unstakeDelaySec, 0xffffffff))

			if iszero(call(gas(), entryPoint, callvalue(), ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unlockStake(address entryPoint) external payable onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xbb9fe6bf00000000000000000000000000000000000000000000000000000000) // unlockStake()

			if iszero(call(gas(), entryPoint, 0x00, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function withdrawStake(address entryPoint, address recipient) external payable onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xc23a5cea00000000000000000000000000000000000000000000000000000000) // withdrawStake(address)
			mstore(add(ptr, 0x04), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), entryPoint, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
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
			mstore(0x00, and(factory, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(0x20, WHITELISTS_SLOT)

			flag := sload(keccak256(0x00, 0x40))
		}
	}
}
