// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModuleFactory} from "src/interfaces/factories/IModuleFactory.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title NativeWrapperFallback
/// @notice Fallback module that allows smart accounts to wrap and unwrap wrapped native token
contract NativeWrapperFallback is FallbackBase {
	/// @notice Thrown when trying to wrap/unwrap tokens by insufficient amount
	error InsufficientBalance();

	/// @notice Thrown when the provided currency is invalid
	error InvalidCurrency();

	mapping(address account => bool isInstalled) internal _isInstalled;

	/// @notice The address of the wrapped native token
	Currency public immutable WRAPPED_NATIVE;

	constructor() {
		bytes memory context = IModuleFactory(msg.sender).parameters();
		Currency wrappedNative;

		assembly ("memory-safe") {
			if lt(mload(context), 0x20) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			wrappedNative := shr(0x60, shl(0x60, mload(add(context, 0x20))))
			if iszero(wrappedNative) {
				mstore(0x00, 0xf5993428) // InvalidCurrency()
				revert(0x1c, 0x04)
			}
		}

		WRAPPED_NATIVE = wrappedNative;
	}

	/// @notice Initialize the module with the given data
	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	/// @notice De-initialize the module with the given data
	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	/// @notice Check if the module is initialized for the given smart account
	/// @param account The address of the smart account
	/// @return True if the module is initialized, false otherwise
	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	/// @notice Wraps the given amount of ETH in order to receive WETH by invoking `deposit()`
	/// @param amount The amount of the ETH
	function wrap(uint256 amount) external payable {
		_wrap(WRAPPED_NATIVE, amount);
	}

	/// @notice Unwraps the given amount of WETH in order to receive ETH by invoking `withdraw(uint256)`
	/// @param amount The amount of the WETH
	function unwrap(uint256 amount) external payable {
		require(WRAPPED_NATIVE.balanceOfSelf() >= amount, InsufficientBalance());
		_unwrap(WRAPPED_NATIVE, amount);
	}

	/// @notice Returns the name of the module
	/// @return The name of the module
	function name() external pure returns (string memory) {
		return "NativeWrapperFallback";
	}

	/// @notice Returns the version of the module
	/// @return The version of the module
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	/// @notice Checks if the module is of the specified type
	/// @param moduleTypeId The module type ID to check
	/// @return True if the module is of the specified type, false otherwise
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_FALLBACK;
	}

	function _wrap(Currency wrappedNative, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			if lt(selfbalance(), amount) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			mstore(0x00, 0xd0e30db0) // deposit()

			if iszero(call(gas(), wrappedNative, amount, 0x1c, 0x04, codesize(), 0x00)) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _unwrap(Currency wrappedNative, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000) // withdraw(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), wrappedNative, 0x00, ptr, 0x24, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _isInitialized(address account) internal view virtual returns (bool result) {
		return _isInstalled[account];
	}
}
