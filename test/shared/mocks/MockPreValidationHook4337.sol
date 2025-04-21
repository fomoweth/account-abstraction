// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPreValidationHookERC4337} from "src/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ModuleBase} from "src/modules/base/ModuleBase.sol";

contract MockPreValidationHook4337 is IPreValidationHookERC4337, ModuleBase {
	event PreValidationOnInstallCalled(bytes32 indexed word);
	event PreValidation4337Called();

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
		return moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC4337;
	}

	function preValidationHookERC4337(
		PackedUserOperation calldata userOp,
		uint256 missingAccountFunds,
		bytes32 userOpHash
	) external virtual returns (bytes32 hookHash, bytes memory hookSignature) {
		// emit PreValidation4337Called();
		missingAccountFunds;
		return (userOpHash, userOp.signature);
	}
}
