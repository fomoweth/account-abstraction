// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IStatelessValidator} from "src/interfaces/IERC7579Modules.sol";
import {PolicyType, SmartSessionMode, ActionId, PermissionId, ModuleType, ValidationData} from "src/types/DataTypes.sol";

struct EnableSession {
	uint8 chainDigestIndex;
	ChainDigest[] hashesAndChainIds;
	Session sessionToEnable;
	bytes permissionEnableSig;
}

struct ChainDigest {
	uint64 chainId;
	bytes32 sessionDigest;
}

struct Session {
	IStatelessValidator sessionValidator;
	bytes sessionValidatorInitData;
	bytes32 salt;
	PolicyData[] userOpPolicies;
	ERC7739Data erc7739Policies;
	ActionData[] actions;
}

struct ActionData {
	bytes4 actionTargetSelector;
	address actionTarget;
	PolicyData[] actionPolicies;
}

struct PolicyData {
	address policy;
	bytes initData;
}

struct ERC7739Data {
	string[] allowedERC7739Content;
	PolicyData[] erc1271Policies;
}

interface ISmartSession {
	error AssociatedArray_OutOfBounds(uint256 index);
	error ChainIdMismatch(uint64 providedChainId);
	error HashIndexOutOfBounds(uint256 index);
	error HashMismatch(bytes32 providedHash, bytes32 computedHash);
	error InvalidData();
	error InvalidActionId();
	error NoExecutionsInBatch();
	error InvalidTarget();
	error InvalidEnableSignature(address account, bytes32 hash);
	error InvalidISessionValidator(IStatelessValidator sessionValidator);
	error InvalidSelfCall();
	error InvalidSession(PermissionId permissionId);
	error InvalidSessionKeySignature(
		PermissionId permissionId,
		address sessionValidator,
		address account,
		bytes32 userOpHash
	);
	error SmartSessionModuleAlreadyInstalled(address account);
	error InvalidPermissionId(PermissionId permissionId);
	error InvalidCallTarget();
	error InvalidUserOpSender(address sender);
	error NoPoliciesSet(PermissionId permissionId);
	error PartlyEnabledActions();
	error PartlyEnabledPolicies();
	error PolicyViolation(PermissionId permissionId, address policy);
	error SignerNotFound(PermissionId permissionId, address account);
	error UnsupportedExecutionType();
	error UnsupportedPolicy(address policy);
	error UnsupportedSmartSessionMode(SmartSessionMode mode);
	error ForbiddenValidationData();

	event NonceIterated(PermissionId permissionId, address account, uint256 newValue);
	event SessionValidatorEnabled(PermissionId permissionId, address sessionValidator, address smartAccount);
	event SessionValidatorDisabled(PermissionId permissionId, address sessionValidator, address smartAccount);
	event PolicyDisabled(PermissionId permissionId, PolicyType policyType, address policy, address smartAccount);
	event ActionIdDisabled(PermissionId permissionId, ActionId actionId, address smartAccount);
	event PolicyEnabled(PermissionId permissionId, PolicyType policyType, address policy, address smartAccount);
	event SessionCreated(PermissionId permissionId, address account);
	event SessionRemoved(PermissionId permissionId, address smartAccount);

	// ERC7579 Module Interface

	/**
	 * ERC4337/ERC7579 validation function
	 * the primary purpose of this function, is to validate if a userOp forwarded by a 7579 account
	 * is valid.
	 * This function will dissect the userop.signature field, and parse out the provided
	 * PermissionId, which identifies
	 * a
	 * unique ID of a dapp for a specific user. n Policies and one Signer contract are mapped to
	 * this Id and will be
	 * checked. Only UserOps that pass policies and signer checks, are considered valid.
	 * Enable Flow:
	 *     SmartSessions allows session keys to be created within the "first" UserOp. If the enable
	 * flow is chosen, the
	 *     EnableSession data, which is packed in userOp.signature is parsed, and stored in the
	 * SmartSession storage.
	 *
	 */
	function validateUserOp(PackedUserOperation memory userOp, bytes32 userOpHash) external returns (ValidationData vd);

	/**
	 * ERC7579 compliant onInstall function.
	 * expected to abi.encode(Session[]) for the enable data
	 *
	 * Note: It's possible to install the smartsession module with data = ""
	 */
	function onInstall(bytes memory data) external;

	/**
	 * ERC7579 compliant uninstall function.
	 * will wipe all configIds and associated Policies / Signers
	 */
	function onUninstall(bytes memory) external;

	/**
	 * ERC7579 compliant ERC1271 function
	 * this function allows session keys to sign ERC1271 requests.
	 */
	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes memory signature
	) external view returns (bytes4 result);

	function isInitialized(address smartAccount) external view returns (bool);

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool);

	// Sessions Management

	function enableActionPolicies(PermissionId permissionId, ActionData[] memory actionPolicies) external;

	function enableERC1271Policies(PermissionId permissionId, ERC7739Data calldata erc1271Policies) external;

	function enableSessions(Session[] memory sessions) external returns (PermissionId[] memory permissionIds);

	function enableUserOpPolicies(PermissionId permissionId, PolicyData[] memory userOpPolicies) external;

	function disableActionPolicies(PermissionId permissionId, ActionId actionId, address[] memory policies) external;

	function disableActionId(PermissionId permissionId, ActionId actionId) external;

	function disableERC1271Policies(
		PermissionId permissionId,
		address[] memory policies,
		string[] calldata contents
	) external;

	function disableUserOpPolicies(PermissionId permissionId, address[] memory policies) external;

	function removeSession(PermissionId permissionId) external;

	function revokeEnableSignature(PermissionId permissionId) external;

	// View Functions

	function getSessionDigest(
		PermissionId permissionId,
		address account,
		Session memory data,
		SmartSessionMode mode
	) external view returns (bytes32);

	function getNonce(PermissionId permissionId, address account) external view returns (uint256);

	function getPermissionId(Session memory session) external pure returns (PermissionId permissionId);

	function isPermissionEnabled(PermissionId permissionId, address account) external view returns (bool);

	function isISessionValidatorSet(PermissionId permissionId, address account) external view returns (bool);

	function areUserOpPoliciesEnabled(
		address account,
		PermissionId permissionId,
		PolicyData[] calldata userOpPolicies
	) external view returns (bool);

	function areERC1271PoliciesEnabled(
		address account,
		PermissionId permissionId,
		PolicyData[] calldata erc1271Policies
	) external view returns (bool);

	function areActionsEnabled(
		address account,
		PermissionId permissionId,
		ActionData[] calldata actions
	) external view returns (bool);
}
