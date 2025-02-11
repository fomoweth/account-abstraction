// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/modules/IERC7579Modules.sol";

/// @title ModuleBase

abstract contract ModuleBase is IModule {
	error InvalidDataLength();

	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function name() external view virtual returns (string memory);

	function version() external view virtual returns (string memory);

	function _isInitialized(address account) internal view virtual returns (bool);
}
