// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISmartAccountFactory} from "src/interfaces/factories/ISmartAccountFactory.sol";
import {ERC1967Clone} from "src/libraries/ERC1967Clone.sol";

/// @title SmartAccountFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using a factory pattern

contract SmartAccountFactory is ISmartAccountFactory {
	using ERC1967Clone for address;

	/// @dev keccak256(bytes("AccountCreated(address,bytes32)"))
	bytes32 private constant ACCOUNT_CREATED_TOPIC = 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951;

	address public immutable implementation;

	constructor(address _implementation) {
		assembly ("memory-safe") {
			if iszero(extcodesize(_implementation)) {
				mstore(0x00, 0xeb30c926) // InvalidAccountImplementation()
				revert(0x1c, 0x04)
			}
		}

		implementation = _implementation;
	}

	function createAccount(bytes calldata data, bytes32 salt) public payable virtual returns (address payable) {
		(bool alreadyDeployed, address account) = implementation.createDeterministic(encodeSalt(data, salt));

		assembly ("memory-safe") {
			if iszero(alreadyDeployed) {
				let ptr := mload(0x40)

				mstore(ptr, 0x4b6a141900000000000000000000000000000000000000000000000000000000) // initializeAccount(bytes)
				mstore(add(ptr, 0x04), 0x20)
				mstore(add(ptr, 0x24), data.length)
				calldatacopy(add(ptr, 0x44), data.offset, data.length)

				if iszero(call(gas(), account, 0x00, ptr, add(data.length, 0x44), codesize(), 0x00)) {
					mstore(0x00, 0x19b991a8) // InitializationFailed()
					revert(0x1c, 0x04)
				}

				log3(codesize(), 0x00, ACCOUNT_CREATED_TOPIC, account, salt)
			}
		}

		return payable(account);
	}

	function computeAddress(bytes calldata data, bytes32 salt) public view virtual returns (address payable) {
		return payable(implementation.predictDeterministicAddress(encodeSalt(data, salt)));
	}

	function encodeSalt(bytes calldata data, bytes32 salt) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			calldatacopy(ptr, data.offset, data.length)
			mstore(add(ptr, data.length), salt)
			digest := keccak256(ptr, add(data.length, 0x20))

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}
}
