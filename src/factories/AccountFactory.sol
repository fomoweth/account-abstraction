// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountFactory} from "src/interfaces/factories/IAccountFactory.sol";

/// @title AccountFactory

contract AccountFactory is IAccountFactory {
	/// @dev keccak256("AccountCreated(address,bytes32)")
	bytes32 internal constant ACCOUNT_CREATED_TOPIC =
		0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951;

	address public immutable ACCOUNT_IMPLEMENTATION;

	constructor(address implementation) {
		assembly ("memory-safe") {
			implementation := shr(0x60, shl(0x60, implementation))
			if iszero(implementation) {
				mstore(0x00, 0xeb30c926) // InvalidAccountImplementation()
				revert(0x1c, 0x04)
			}
		}

		ACCOUNT_IMPLEMENTATION = implementation;
	}

	function createAccount(bytes32 salt, bytes calldata data) public payable virtual returns (address payable account) {
		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, data);
	}

	function _createAccount(
		address implementation,
		bytes32 salt,
		bytes memory data
	) internal virtual returns (address payable account) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
			mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
			mstore(0x20, 0x6009)
			mstore(0x1e, implementation)
			mstore(0x0a, 0x603d3d8160223d3973)

			mstore(add(ptr, 0x35), keccak256(0x21, 0x5f))
			mstore(ptr, shl(0x58, address()))
			mstore8(ptr, 0xff)
			mstore(add(ptr, 0x15), salt)

			account := keccak256(ptr, 0x55)

			// prettier-ignore
			for { } 0x01 { } {
				if iszero(extcodesize(account)) {
					account := create2(callvalue(), 0x21, 0x5f, salt)

					if iszero(account) {
						mstore(0x00, 0x20188a59) // AccountCreationFailed()
						revert(0x1c, 0x04)
					}

					if iszero(call(gas(), account, 0x00, add(data, 0x20), mload(data), codesize(), 0x00)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					log3(codesize(), 0x00, ACCOUNT_CREATED_TOPIC, account, salt)

					break
				}

				if iszero(callvalue()) { break }
				if iszero(call(gas(), account, callvalue(), codesize(), 0x00, codesize(), 0x00)) {
					mstore(0x00, 0xb12d13eb) // ETHTransferFailed()
					revert(0x1c, 0x04)
				}

				break
			}

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}

	function computeAddress(bytes32 salt) public view virtual returns (address payable account) {
		return _computeAddress(ACCOUNT_IMPLEMENTATION, salt);
	}

	function _computeAddress(
		address implementation,
		bytes32 salt
	) internal view virtual returns (address payable account) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
			mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
			mstore(0x20, 0x6009)
			mstore(0x1e, implementation)
			mstore(0x0a, 0x603d3d8160223d3973)

			mstore(add(ptr, 0x35), keccak256(0x21, 0x5f))
			mstore(ptr, shl(0x58, address()))
			mstore8(ptr, 0xff)
			mstore(add(ptr, 0x15), salt)

			account := keccak256(ptr, 0x55)

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}
}
