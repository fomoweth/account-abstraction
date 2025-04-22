// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPreValidationHookERC1271} from "src/interfaces/IERC7579Modules.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/base/ModuleBase.sol";

contract MockPreValidationHook1271 is IPreValidationHookERC1271, ModuleBase {
	event PreValidationOnInstallCalled(bytes32 indexed word);

	mapping(address account => bool) internal _isInstalled;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		if (data.length >= 0x20) emit PreValidationOnInstallCalled(bytes32(data[0:32]));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function _isInitialized(address account) internal view virtual returns (bool) {
		return _isInstalled[account];
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC1271;
	}

	function preValidationHookERC1271(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view virtual returns (bytes32 hookHash, bytes memory hookSignature) {
		sender;
		return (hash, signature);
	}
}
