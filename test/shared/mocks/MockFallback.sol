// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/IERC7579Modules.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ModuleLib} from "src/libraries/ModuleLib.sol";
import {ExecutionModeLib, CallType} from "src/types/ExecutionMode.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockFallback is IFallback, ModuleBase {
	using CalldataDecoder for bytes;

	mapping(address account => bytes4[] selectors) public registeredSelectors;

	function onInstall(bytes calldata data) public payable {
		if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

		bytes4[] calldata selectors = data.decodeSelectors(0);
		uint256 length = selectors.length;

		for (uint256 i; i < length; ++i) {
			registeredSelectors[msg.sender].push(selectors[i]);
		}
	}

	function onUninstall(bytes calldata) public payable {
		if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
		delete registeredSelectors[msg.sender];
	}

	function register(bytes4[] calldata selectors) public {
		uint256 length = selectors.length;
		for (uint256 i; i < length; ++i) {
			registeredSelectors[msg.sender].push(selectors[i]);
		}
	}

	function isInitialized(address account) public view returns (bool) {
		return registeredSelectors[account].length != 0;
	}

	function getRegisteredSelectors(address account) public view returns (bytes4[] memory selectors) {
		return registeredSelectors[account];
	}

	function getSupportedCalls() public pure returns (bytes4[] memory selectors, CallType[] memory callTypes) {
		selectors = new bytes4[](2);
		selectors[0] = 0x095ea7b3;
		selectors[1] = this.register.selector;

		callTypes = new CallType[](2);
		callTypes[0] = ExecutionModeLib.CALLTYPE_DELEGATE;
		callTypes[1] = ExecutionModeLib.CALLTYPE_SINGLE;
	}

	function name() public pure returns (string memory) {
		return "MockFallback";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(uint256 moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_FALLBACK;
	}
}
