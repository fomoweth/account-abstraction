// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4337Account} from "./IERC4337Account.sol";
import {IERC7579Account} from "./IERC7579Account.sol";

interface IVortex is IERC4337Account, IERC7579Account {
	function initializeAccount(bytes calldata data) external payable;
}
