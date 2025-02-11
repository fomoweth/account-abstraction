// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHook} from "src/interfaces/modules/IERC7579Modules.sol";
import {ModuleType, MODULE_TYPE_HOOK} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockHook is IHook, ModuleBase {
	event Log(address msgSender, uint256 msgValue, bytes msgData);

	mapping(address account => bool isInstalled) public isInstalled;

	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) public payable returns (bytes memory hookData) {
		hookData = abi.encode(msgSender, msgValue, msgData);
	}

	function postCheck(bytes calldata hookData) public payable {
		address msgSender;
		uint256 msgValue;
		bytes calldata msgData;
		assembly ("memory-safe") {
			msgSender := shr(0x60, calldataload(hookData.offset))
			msgValue := calldataload(add(hookData.offset, 0x14))
			msgData.offset := add(hookData.offset, 0x34)
			msgData.length := sub(hookData.length, 0x34)
		}

		// emit Log(msgSender, msgValue, msgData);
	}

	function onInstall(bytes calldata) public payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) public payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		isInstalled[msg.sender] = false;
	}

	function _isInitialized(address account) internal view virtual override returns (bool) {
		return isInstalled[account];
	}

	function name() public pure virtual override returns (string memory) {
		return "MockHook";
	}

	function version() public pure virtual override returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_HOOK;
	}
}
