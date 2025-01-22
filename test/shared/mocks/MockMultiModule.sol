// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockMultiModule is ModuleBase {
	mapping(address account => bool isInstalled) public isInstalled;

	function onInstall(bytes calldata data) public payable {
		if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);
		data;
		isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) public payable {
		if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
		isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) public view returns (bool) {
		return isInstalled[account];
	}

	function name() public pure returns (string memory) {
		return "MockMultiModule";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(uint256 moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_MULTI;
	}
}
