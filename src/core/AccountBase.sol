// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

/// @title AccountBase
/// @notice Implements ERC-4337 and ERC-7579 standards for account management and access control

abstract contract AccountBase {
	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

	modifier onlyEntryPoint() {
		assembly ("memory-safe") {
			if xor(caller(), ENTRYPOINT) {
				mstore(0x00, 0x82b42900) // Unauthorized()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	modifier onlyEntryPointOrSelf() {
		assembly ("memory-safe") {
			if and(xor(caller(), ENTRYPOINT), xor(caller(), address())) {
				mstore(0x00, 0x82b42900) // Unauthorized()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	modifier payPrefund(uint256 missingAccountFunds) {
		_;
		assembly ("memory-safe") {
			if missingAccountFunds {
				pop(call(gas(), caller(), missingAccountFunds, codesize(), 0x00, codesize(), 0x00))
			}
		}
	}

	function entryPoint() external pure returns (IEntryPoint) {
		return IEntryPoint(ENTRYPOINT);
	}

	function addDeposit() external payable {
		assembly ("memory-safe") {
			if iszero(call(gas(), ENTRYPOINT, callvalue(), codesize(), 0x00, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	function withdrawDepositTo(address recipient, uint256 amount) external payable onlyEntryPointOrSelf {
		assembly ("memory-safe") {
			recipient := shr(0x60, shl(0x60, recipient))
			if iszero(recipient) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x205c287800000000000000000000000000000000000000000000000000000000) // withdrawTo(address,uint256)
			mstore(add(ptr, 0x04), recipient)
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), ENTRYPOINT, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(ptr, 0x00)
			mstore(add(ptr, 0x20), 0x00)
			mstore(add(ptr, 0x40), 0x00)
		}
	}

	function getDeposit() external view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000) // balanceOf(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))

			// prettier-ignore
			value := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x24, 0x00,0x20)))
		}
	}

	function nonce(uint192 key) external view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x35567e1a00000000000000000000000000000000000000000000000000000000) // getNonce(address,uint192)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))
			mstore(add(ptr, 0x24), key)

			// prettier-ignore
			value := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x44, 0x00, 0x20)))
		}
	}
}
