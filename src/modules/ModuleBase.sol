// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule} from "src/interfaces/IERC7579Modules.sol";

/// @title ModuleBase

abstract contract ModuleBase is IModule {
	error InvalidDataLength();

	address internal constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

	uint256 internal constant MODULE_TYPE_MULTI = 0;
	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;
	uint256 internal constant MODULE_TYPE_POLICY = 5;
	uint256 internal constant MODULE_TYPE_SIGNER = 6;

	uint256 internal constant VALIDATION_SUCCESS = 0;
	uint256 internal constant VALIDATION_FAILED = 1;

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function name() external view virtual returns (string memory);

	function version() external view virtual returns (string memory);

	function _isInitialized(address account) internal view virtual returns (bool);
}
