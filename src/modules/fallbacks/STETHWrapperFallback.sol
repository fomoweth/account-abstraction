// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback, IModule} from "src/interfaces/IERC7579Modules.sol";
import {IModuleFactory} from "src/interfaces/factories/IModuleFactory.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title STETHWrapperFallback
/// @notice Fallback module that enables smart accounts to wrap and unwrap stETH and wstETH.
contract STETHWrapperFallback is IFallback, FallbackBase {
	/// @notice Thrown when trying to wrap/unwrap tokens by insufficient amount
	error InsufficientBalance();

	/// @notice Thrown when the provided currency is invalid
	error InvalidCurrency();

	/// @notice The address of the stETH
	Currency public immutable STETH;

	/// @notice The address of the wstETH
	Currency public immutable WSTETH;

	constructor() {
		bytes memory context = IModuleFactory(msg.sender).parameters();
		Currency stETH;
		Currency wstETH;

		assembly ("memory-safe") {
			if lt(mload(context), 0x40) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			stETH := shr(0x60, shl(0x60, mload(add(context, 0x20))))
			if iszero(stETH) {
				mstore(0x00, 0xf5993428) // InvalidCurrency()
				revert(0x1c, 0x04)
			}

			wstETH := shr(0x60, shl(0x60, mload(add(context, 0x40))))
			if iszero(wstETH) {
				mstore(0x00, 0xf5993428) // InvalidCurrency()
				revert(0x1c, 0x04)
			}
		}

		STETH = stETH;
		WSTETH = wstETH;
	}

	/// @inheritdoc IModule
	function onInstall(bytes calldata) external payable {}

	/// @inheritdoc IModule
	function onUninstall(bytes calldata) external payable {}

	/// @inheritdoc IModule
	function isInitialized(address) external pure returns (bool) {
		return true;
	}

	/// @notice Wraps the given amount of ETH and receive stETH by transferring ETH
	/// @param amount The amount of the ETH
	function wrapSTETH(uint256 amount) external payable {
		_wrapSTETH(STETH, amount);
	}

	/// @notice Wraps the given amount of stETH and receive wstETH by invoking `wrap(uint256)`
	/// @param amount The amount of the stETH
	function wrapWSTETH(uint256 amount) external payable {
		require(STETH.balanceOfSelf() >= amount, InsufficientBalance());
		_wrapWSTETH(WSTETH, amount);
	}

	/// @notice Unwraps the given amount of wstETH and receive stETH by invoking `unwrap(uint256)`
	/// @param amount The amount of the wstETH
	function unwrapWSTETH(uint256 amount) external payable {
		require(WSTETH.balanceOfSelf() >= amount, InsufficientBalance());
		_unwrapWSTETH(WSTETH, amount);
	}

	/// @notice Returns the name of the module
	/// @return The name of the module
	function name() external pure returns (string memory) {
		return "STETHWrapperFallback";
	}

	/// @notice Returns the version of the module
	/// @return The version of the module
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	/// @inheritdoc IModule
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_FALLBACK;
	}

	function _wrapSTETH(Currency stETH, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			if lt(selfbalance(), amount) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			if iszero(call(gas(), stETH, amount, codesize(), 0x00, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	function _wrapWSTETH(Currency wstETH, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xea598cb000000000000000000000000000000000000000000000000000000000) // wrap(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), wstETH, 0x00, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _unwrapWSTETH(Currency wstETH, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000) // unwrap(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), wstETH, 0x00, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}
}
