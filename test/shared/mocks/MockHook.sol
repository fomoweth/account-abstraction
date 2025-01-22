// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockHook is IHook, ModuleBase {
	mapping(address account => bool isInstalled) public isInstalled;

	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) public payable returns (bytes memory hookData) {
		//
	}

	function postCheck(bytes calldata hookData) public payable {
		//
	}

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
		return "MockHook";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(uint256 moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_HOOK;
	}
}
