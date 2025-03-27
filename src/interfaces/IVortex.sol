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
}
