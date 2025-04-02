// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title NativeWrapper

contract NativeWrapper is FallbackBase {
	error InsufficientBalance();

	mapping(address account => bool isInstalled) internal _isInstalled;

	Currency public immutable WRAPPED_NATIVE;

	constructor() {
		bytes memory context = IMetaFactory(msg.sender).parameters();
		Currency wrappedNative;

		assembly ("memory-safe") {
			if lt(mload(context), 0x20) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			wrappedNative := shr(0x60, shl(0x60, mload(add(context, 0x20))))
		}

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
		_wrapETH(WRAPPED_NATIVE, amount);
	}

	function unwrapWETH(uint256 amount) external payable {
		require(WRAPPED_NATIVE.balanceOfSelf() >= amount, InsufficientBalance());
		_unwrapWETH(WRAPPED_NATIVE, amount);
	}

	function _wrapETH(Currency wrappedNative, uint256 amount) private {
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

	function _unwrapWETH(Currency wrappedNative, uint256 amount) private {
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
