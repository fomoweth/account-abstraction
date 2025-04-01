// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title STETHWrapper

contract STETHWrapper is FallbackBase {
	error InsufficientBalance();

	mapping(address account => bool isInstalled) internal _isInstalled;

	Currency public immutable STETH;
	Currency public immutable WSTETH;

	constructor(Currency stETH, Currency wstETH) {
		STETH = stETH;
		WSTETH = wstETH;
	}

	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function wrapSTETH(uint256 amount) external payable {
		_wrapSTETH(STETH, amount);
	}

	function wrapWSTETH(uint256 amount) external payable {
		require(STETH.balanceOfSelf() >= amount, InsufficientBalance());
		_wrapWSTETH(WSTETH, amount);
	}

	function unwrapWSTETH(uint256 amount) external payable {
		require(WSTETH.balanceOfSelf() >= amount, InsufficientBalance());
		_unwrapWSTETH(WSTETH, amount);
	}

	function _wrapSTETH(Currency stETH, uint256 amount) internal virtual {
		assembly ("memory-safe") {
			if iszero(stETH) {
				mstore(0x00, 0x226f153d) // UnsupportedExecution()
				revert(0x1c, 0x04)
			}

			if lt(selfbalance(), amount) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xa1903eab00000000000000000000000000000000000000000000000000000000) // submit(address)

			if iszero(call(gas(), stETH, amount, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
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

	function name() external pure returns (string memory) {
		return "STETHWrapper";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_FALLBACK;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _isInstalled[account];
	}
}
