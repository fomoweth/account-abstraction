// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4337Account} from "src/interfaces/IERC4337Account.sol";
import {AccessControl} from "./AccessControl.sol";

/// @title AccountBase

abstract contract AccountBase is IERC4337Account, AccessControl {
	string internal constant ACCOUNT_IMPLEMENTATION_ID = "fomoweth.vortex.1.0.0";

	modifier payPrefund(uint256 missingAccountFunds) {
		_;
		_payPrefund(missingAccountFunds);
	}

	function addDeposit() external payable {
		assembly ("memory-safe") {
			if iszero(call(gas(), ENTRYPOINT, callvalue(), codesize(), 0x00, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	function withdrawTo(address recipient, uint256 amount) external payable onlyEntryPointOrSelf {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x205c287800000000000000000000000000000000000000000000000000000000) // withdrawTo(address,uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), ENTRYPOINT, 0x00, ptr, 0x44, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getDeposit() external view returns (uint256 deposit) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000) // balanceOf(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))

			// prettier-ignore
			deposit := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x24, 0x00,0x20)))
		}
	}

	function getNonce(uint192 key) external view returns (uint256 nonce) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x35567e1a00000000000000000000000000000000000000000000000000000000) // getNonce(address,uint192)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))
			mstore(add(ptr, 0x24), shr(0x40, shl(0x40, key)))

			// prettier-ignore
			nonce := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ENTRYPOINT, ptr, 0x44, 0x00, 0x20)))
		}
	}

	function _payPrefund(uint256 missingAccountFunds) internal virtual {
		assembly ("memory-safe") {
			if missingAccountFunds {
				pop(call(gas(), caller(), missingAccountFunds, codesize(), 0x00, codesize(), 0x00))
			}
		}
	}
}
