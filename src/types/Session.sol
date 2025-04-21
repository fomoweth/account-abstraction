// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type PermissionId is bytes32;

type ActionId is bytes32;

type ActionPolicyId is bytes32;

type UserOpPolicyId is bytes32;

type Erc1271PolicyId is bytes32;

type ConfigId is bytes32;

enum SmartSessionMode {
	USE,
	ENABLE,
	UNSAFE_ENABLE
}

enum PolicyType {
	NA,
	USER_OP,
	ACTION,
	ERC1271
}

using SessionLib for SmartSessionMode global;
using SessionLib for PermissionId global;
using SessionLib for ActionPolicyId global;
using SessionLib for Erc1271PolicyId global;
using SessionLib for UserOpPolicyId global;

using {eqPermissionId as ==, neqPermissionId as !=} for PermissionId global;
using {eqActionId as ==, neqActionId as !=} for ActionId global;
using {eqActionPolicyId as ==, neqActionPolicyId as !=} for ActionPolicyId global;
using {eqUserOpPolicyId as ==, neqUserOpPolicyId as !=} for UserOpPolicyId global;
using {eqErc1271PolicyId as ==, neqErc1271PolicyId as !=} for Erc1271PolicyId global;
using {eqConfigId as ==, neqConfigId as !=} for ConfigId global;

function eqPermissionId(PermissionId x, PermissionId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqPermissionId(PermissionId x, PermissionId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqActionId(ActionId x, ActionId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqActionId(ActionId x, ActionId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqActionPolicyId(ActionPolicyId x, ActionPolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqActionPolicyId(ActionPolicyId x, ActionPolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqUserOpPolicyId(UserOpPolicyId x, UserOpPolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqUserOpPolicyId(UserOpPolicyId x, UserOpPolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqErc1271PolicyId(Erc1271PolicyId x, Erc1271PolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqErc1271PolicyId(Erc1271PolicyId x, Erc1271PolicyId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqConfigId(ConfigId x, ConfigId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqConfigId(ConfigId x, ConfigId y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title SessionLib
/// @notice Provides utility functions for SmartSession module
library SessionLib {
	bytes4 internal constant VALUE_SELECTOR = 0xFFFFFFFF;

	function isUseMode(SmartSessionMode mode) internal pure returns (bool) {
		return mode == SmartSessionMode.USE;
	}

	function isEnableMode(SmartSessionMode mode) internal pure returns (bool) {
		return mode == SmartSessionMode.ENABLE || mode == SmartSessionMode.UNSAFE_ENABLE;
	}

	function useRegistry(SmartSessionMode mode) internal pure returns (bool) {
		return mode == SmartSessionMode.ENABLE;
	}

	function unpackMode(
		bytes calldata packed
	) internal pure returns (SmartSessionMode mode, PermissionId permissionId, bytes calldata data) {
		mode = SmartSessionMode(uint8(bytes1(packed[:1])));
		if (isEnableMode(mode)) {
			data = packed[1:];
		} else {
			permissionId = PermissionId.wrap(bytes32(packed[1:33]));
			data = packed[33:];
		}
	}

	function encodeUse(PermissionId permissionId, bytes memory signature) internal pure returns (bytes memory userOpSig) {
		return abi.encodePacked(SmartSessionMode.USE, permissionId, signature);
	}

	function toUserOpPolicyId(PermissionId permissionId) internal pure returns (UserOpPolicyId userOpPolicyId) {
		return UserOpPolicyId.wrap(PermissionId.unwrap(permissionId));
	}

	function toActionId(address target, bytes calldata callData) internal pure returns (ActionId actionId) {
		return toActionId(target, callData.length < 4 ? VALUE_SELECTOR : bytes4(callData[:4]));
	}

	function toActionId(address target, bytes4 selector) internal pure returns (ActionId actionId) {
		return ActionId.wrap(keccak256(abi.encodePacked(target, selector)));
	}

	function toActionPolicyId(
		PermissionId permissionId,
		ActionId actionId
	) internal pure returns (ActionPolicyId policyId) {
		return ActionPolicyId.wrap(keccak256(abi.encodePacked(permissionId, actionId)));
	}

	function toErc1271PolicyId(PermissionId permissionId) internal pure returns (Erc1271PolicyId erc1271PolicyId) {
		return Erc1271PolicyId.wrap(keccak256(abi.encodePacked("ERC1271: ", permissionId)));
	}

	function toConfigId(UserOpPolicyId userOpPolicyId, address account) internal pure returns (ConfigId configId) {
		return ConfigId.wrap(keccak256(abi.encodePacked(account, userOpPolicyId)));
	}

	function toConfigId(ActionPolicyId actionPolicyId, address account) internal pure returns (ConfigId configId) {
		return ConfigId.wrap(keccak256(abi.encodePacked(account, actionPolicyId)));
	}

	function toConfigId(
		PermissionId permissionId,
		ActionId actionId,
		address account
	) internal pure returns (ConfigId configId) {
		return toConfigId(toActionPolicyId(permissionId, actionId), account);
	}

	function toConfigId(Erc1271PolicyId erc1271PolicyId, address account) internal pure returns (ConfigId configId) {
		return ConfigId.wrap(keccak256(abi.encodePacked(account, erc1271PolicyId)));
	}

	function toConfigId(UserOpPolicyId userOpPolicyId) internal view returns (ConfigId configId) {
		return toConfigId(userOpPolicyId, msg.sender);
	}

	function toConfigId(PermissionId permissionId, ActionId actionId) internal view returns (ConfigId configId) {
		return toConfigId(toActionPolicyId(permissionId, actionId), msg.sender);
	}

	function toConfigId(Erc1271PolicyId erc1271PolicyId) internal view returns (ConfigId configId) {
		return toConfigId(erc1271PolicyId, msg.sender);
	}
}
