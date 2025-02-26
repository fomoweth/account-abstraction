// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {Vortex} from "src/Vortex.sol";

import {ExecutionUtils, Execution} from "test/shared/utils/ExecutionUtils.sol";
import {UserOpUtils} from "test/shared/utils/UserOpUtils.sol";

using SignerHelper for Signer global;

struct Signer {
	Vortex account;
	bytes10 keyword;
	address payable eoa;
	uint256 publicKeyX;
	uint256 publicKeyY;
	uint256 privateKey;
}

library SignerHelper {
	using ECDSA for bytes32;
	using ExecutionUtils for ExecType;
	using UserOpUtils for Vortex;

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	/// keccak256(bytes("ModuleEnableMode(address module,uint256 moduleType,bytes32 userOpHash,bytes32 initDataHash)"));
	bytes32 internal constant MODULE_ENABLE_MODE_TYPE_HASH =
		0xbe844ccefa05559a48680cb7fe805b2ec58df122784191aed18f9f315c763e1b;

	/// UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)
	bytes32 internal constant USER_OPERATION_EVENT_TOPIC =
		0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f;

	// UserOperationRevertReason(bytes32,address,uint256,bytes)
	bytes32 internal constant USER_OPERATION_REVERT_REASON_TOPIC =
		0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201;

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	bytes1 internal constant VALIDATION_DEFAULT = 0x00;
	bytes1 internal constant VALIDATION_ENABLE = 0x01;

	function execute(
		Signer memory signer,
		ExecType execType,
		Execution[] memory executions
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(executions, false),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function execute(
		Signer memory signer,
		ExecType execType,
		Execution memory execution
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(execution, false),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function execute(
		Signer memory signer,
		ExecType execType,
		address target,
		uint256 value,
		bytes memory callData
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(target, value, callData, false),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function executeFromExecutor(
		Signer memory signer,
		ExecType execType,
		Execution[] memory executions
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(executions, true),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function executeFromExecutor(
		Signer memory signer,
		ExecType execType,
		Execution memory execution
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(execution, true),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function executeFromExecutor(
		Signer memory signer,
		ExecType execType,
		address target,
		uint256 value,
		bytes memory callData
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(
			execType.encodeExecutionCalldata(target, value, callData, true),
			signer.account.rootValidator()
		);

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function installModule(
		Signer memory signer,
		ModuleType moduleTypeId,
		address module,
		bytes memory data
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		bytes memory callData = abi.encodeCall(Vortex.installModule, (moduleTypeId, module, data));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(callData, signer.account.rootValidator());

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function uninstallModule(
		Signer memory signer,
		ModuleType moduleTypeId,
		address module,
		bytes memory data
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		bytes memory callData = abi.encodeCall(Vortex.uninstallModule, (moduleTypeId, module, data));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.account.buildUserOp(callData, signer.account.rootValidator());

		userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
		userOps[0].signature = signer.sign(userOpHash);

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function enableModule(
		Signer memory signer,
		ModuleType moduleTypeId,
		address module,
		bytes memory data,
		bytes memory callData
	) internal returns (bytes32 userOpHash, VmSafe.Log[] memory logs) {
		address validator = signer.account.rootValidator();

		PackedUserOperation memory userOp = signer.account.buildUserOp(callData, validator, VALIDATION_ENABLE);
		userOpHash = ENTRYPOINT.getUserOpHash(userOp);
		userOp.signature = signer.sign(userOpHash);

		bytes32 structHash = keccak256(
			abi.encode(MODULE_ENABLE_MODE_TYPE_HASH, module, moduleTypeId, userOpHash, keccak256(data))
		);
		bytes32 messageHash = signer.account.hashTypedData(structHash);
		bytes memory enableModeSignature = abi.encodePacked(validator, signer.sign(messageHash));

		bytes memory enableModeData = abi.encodePacked(
			module,
			moduleTypeId,
			bytes4(uint32(data.length)),
			data,
			bytes4(uint32(enableModeSignature.length)),
			enableModeSignature
		);
		userOp.signature = abi.encodePacked(enableModeData, userOp.signature);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = userOp;

		vm.recordLogs();

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		logs = vm.getRecordedLogs();
	}

	function addDeposit(Signer memory signer, uint256 value, address beneficiary) internal {
		vm.assume(value != 0);
		vm.prank(signer.eoa);

		ENTRYPOINT.depositTo{value: value}(beneficiary);

		vm.assertGe(ENTRYPOINT.balanceOf(signer.eoa), value);
	}

	function addStake(Signer memory signer, uint256 value, uint32 unstakeDelaySec) internal {
		vm.assume(value != 0 && unstakeDelaySec != 0);
		vm.prank(signer.eoa);

		ENTRYPOINT.addStake{value: value}(unstakeDelaySec);

		IEntryPoint.DepositInfo memory info = ENTRYPOINT.getDepositInfo(signer.eoa);
		vm.assertTrue(info.staked);
		vm.assertGe(info.stake, value);
		vm.assertEq(info.unstakeDelaySec, unstakeDelaySec);
	}

	function signUserOp(
		Signer memory signer,
		PackedUserOperation memory userOp
	) internal view returns (bytes memory signature) {
		return sign(signer, ENTRYPOINT.getUserOpHash(userOp));
	}

	function sign(Signer memory signer, bytes32 messageHash) internal pure returns (bytes memory signature) {
		bytes32 digest = messageHash.toEthSignedMessageHash();
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, digest);
		signature = abi.encodePacked(r, s, v);
	}

	function resetNonce(Signer memory signer) internal returns (uint64) {
		vm.resetNonce(signer.eoa);
		return vm.getNonce(signer.eoa);
	}

	function setNonce(Signer memory signer, uint64 nonce) internal returns (uint64) {
		uint64 current = vm.getNonce(signer.eoa);
		if (nonce == current) return nonce;

		if (nonce > current) vm.setNonce(signer.eoa, nonce);
		else vm.setNonceUnsafe(signer.eoa, nonce);

		return vm.getNonce(signer.eoa);
	}

	function getNonce(Signer memory signer) internal view returns (uint64 nonce) {
		return vm.getNonce(signer.eoa);
	}
}
