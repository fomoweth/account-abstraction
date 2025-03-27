// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title NativeWrapper

contract NativeWrapper is FallbackBase {
	mapping(address account => bool isInstalled) internal _isInstalled;

	Currency public immutable WRAPPED_NATIVE;

	constructor(Currency wrappedNative) {
		WRAPPED_NATIVE = wrappedNative;
	}

	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function wrapETH(uint256 amount) external payable {
		Currency wrappedNative = WRAPPED_NATIVE;

		assembly ("memory-safe") {
			if lt(selfbalance(), amount) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

			if iszero(call(gas(), wrappedNative, amount, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unwrapWETH(uint256 amount) external payable {
		Currency wrappedNative = WRAPPED_NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000) // withdraw(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), wrappedNative, 0x00, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function name() external pure returns (string memory) {
		return "NativeWrapper";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_FALLBACK;
	}

	function _isInitialized(address account) internal view returns (bool result) {
		return _isInstalled[account];
	}
}
