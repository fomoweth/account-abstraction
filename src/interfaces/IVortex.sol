// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode, CallType, ExecType, ModuleType, PackedModuleTypes} from "src/types/Types.sol";
import {IERC4337Account} from "./IERC4337Account.sol";
import {IERC7579Account} from "./IERC7579Account.sol";

interface IVortex is IERC4337Account, IERC7579Account {
	/**
	 * @notice Initializes the smart account with a validator and custom data.
	 * @param data Encoded data used for the account's configuration during initialization.
	 */
	function initializeAccount(bytes calldata data) external payable;

	// function configureRootValidator(address rootValidator, bytes calldata data) external payable;
	// function configureRegistry(address registry, address[] calldata attesters, uint8 threshold) external payable;
	// function rootValidator() external view returns (address);
	// function registry() external view returns (address);
	// function globalHook() external view returns (address);
	// function fallbackHandler(bytes4 selector) external view returns (CallType callType, address hook);
	// function getConfiguration(
	// 	address module
	// ) external view returns (ModuleType moduleTypeId, PackedModuleTypes packedTypes, address hook);
}
