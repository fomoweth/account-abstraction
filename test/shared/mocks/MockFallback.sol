// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFallback} from "src/interfaces/modules/IERC7579Modules.sol";
import {CallType, CALLTYPE_SINGLE, CALLTYPE_STATIC, CALLTYPE_DELEGATE} from "src/types/ExecutionMode.sol";
import {ModuleType, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/ModuleBase.sol";

contract MockFallback is IFallback, ModuleBase {
	event Log(address sender, bytes callData);

	mapping(address account => bool isInstalled) public isInstalled;

	function onInstall(bytes calldata) public payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) public payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		isInstalled[msg.sender] = false;
	}

	function mockCall(bytes calldata data) public payable virtual {
		emit Log(msg.sender, data);
	}

	function mockDelegate(bytes calldata data) public payable virtual {
		emit Log(msg.sender, data);
	}

	function mockStatic() public view virtual returns (bytes memory data) {
		(bytes4[] memory selectors, CallType[] memory callTypes) = getSupportedCalls();
		data = abi.encode(selectors, callTypes);
	}

	function _isInitialized(address account) internal view virtual override returns (bool) {
		return isInstalled[account];
	}

	function getSupportedCalls() public pure returns (bytes4[] memory selectors, CallType[] memory callTypes) {
		selectors = new bytes4[](3);
		selectors[0] = this.mockCall.selector;
		selectors[1] = this.mockDelegate.selector;
		selectors[2] = this.mockStatic.selector;

		callTypes = new CallType[](3);
		callTypes[0] = CALLTYPE_SINGLE;
		callTypes[1] = CALLTYPE_DELEGATE;
		callTypes[2] = CALLTYPE_STATIC;
	}

	function name() public pure virtual override returns (string memory) {
		return "MockFallback";
	}

	function version() public pure virtual override returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_FALLBACK || moduleTypeId == MODULE_TYPE_EXECUTOR;
	}
}
