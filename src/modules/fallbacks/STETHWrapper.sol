// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

/// @title STETHWrapper

contract STETHWrapper is FallbackBase {
	mapping(address account => bool isInstalled) internal _isInstalled;

	address internal constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
	address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

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
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa1903eab00000000000000000000000000000000000000000000000000000000) // submit(address)

			if iszero(call(gas(), STETH, amount, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function wrapWSTETH(uint256 amount) external payable {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xea598cb000000000000000000000000000000000000000000000000000000000) // wrap(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), WSTETH, 0x00, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unwrapWSTETH(uint256 amount) external payable {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000) // unwrap(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), WSTETH, 0x00, ptr, 0x24, 0x00, 0x20)) {
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
