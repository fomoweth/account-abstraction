// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISmartAccountFactory} from "src/interfaces/ISmartAccountFactory.sol";
import {ERC1967Clone} from "src/libraries/ERC1967Clone.sol";

/// @title SmartAccountFactory

contract SmartAccountFactory is ISmartAccountFactory {
	using ERC1967Clone for address;

	/// @dev keccak256(bytes("AccountCreated(address,address,bytes32)"))
	bytes32 private constant ACCOUNT_CREATED_TOPIC = 0xf66707ae2820569ece31cb5ac7cfcdd4d076c3f31ed9e28bf94394bedc0f329d;

	address public immutable implementation;

	constructor(address _implementation) {
		implementation = _implementation;
	}

	function createAccount(bytes calldata data, bytes32 salt) external payable returns (address payable) {
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

				log4(codesize(), 0x00, ACCOUNT_CREATED_TOPIC, account, caller(), salt)
			}
		}

		return payable(account);
	}

	function computeAddress(bytes calldata data, bytes32 salt) external view returns (address payable) {
		return payable(implementation.predictDeterministicAddress(encodeSalt(data, salt)));
	}

	function encodeSalt(bytes calldata data, bytes32 salt) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(data, salt));
	}
}
