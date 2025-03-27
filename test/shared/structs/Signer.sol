// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IModule} from "src/interfaces/IERC7579Modules.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {SignatureChecker} from "src/libraries/SignatureChecker.sol";
import {VALIDATION_MODE_DEFAULT, VALIDATION_MODE_ENABLE} from "src/types/Constants.sol";
import {ExecType, ModuleType, ValidationMode} from "src/types/Types.sol";
import {Vortex} from "src/Vortex.sol";

import {ExecutionUtils} from "test/shared/utils/ExecutionUtils.sol";

using SignerHelper for Signer global;

struct Signer {
	address payable eoa;
	bytes10 keyword;
	Vortex account;
	uint256 publicKeyX;
	uint256 publicKeyY;
	uint256 privateKey;
}

library SignerHelper {
	using ExecutionUtils for ExecType;
	using SignatureChecker for bytes32;

	event ModuleInstalled(ModuleType indexed moduleTypeId, address indexed module);
	event ModuleUninstalled(ModuleType indexed moduleTypeId, address indexed module);

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	function execute(
		Signer memory signer,
		ExecType execType,
		address target,
		uint256 value,
		bytes memory callData
	) internal returns (PackedUserOperation[] memory userOps, bytes32 userOpHash) {
		return signer.execute(execType.encodeExecutionCalldata(target, value, callData));
	}

	function execute(
		Signer memory signer,
		ExecType execType,
		Execution memory execution
	) internal returns (PackedUserOperation[] memory userOps, bytes32 userOpHash) {
		return signer.execute(execType.encodeExecutionCalldata(execution.target, execution.value, execution.callData));
	}

	function execute(
		Signer memory signer,
		ExecType execType,
		Execution[] memory executions
	) internal returns (PackedUserOperation[] memory userOps, bytes32 userOpHash) {
		return signer.execute(execType.encodeExecutionCalldata(executions));
	}

	function execute(
		Signer memory signer,
		ExecType execType,
		address target,
		bytes memory callData
	) internal returns (PackedUserOperation[] memory userOps, bytes32 userOpHash) {
		return signer.execute(execType.encodeExecutionCalldata(target, callData));
	}

	function execute(
		Signer memory signer,
		bytes memory executionCalldata
	) internal returns (PackedUserOperation[] memory userOps, bytes32 userOpHash) {
		userOps = new PackedUserOperation[](1);
		(userOps[0], userOpHash) = signer.prepareUserOp(executionCalldata);

		ENTRYPOINT.handleOps(userOps, signer.eoa);
	}

	function install(Signer memory signer, ModuleType moduleTypeId, address module, bytes memory data) internal {
		bytes memory callData = abi.encodeCall(Vortex.installModule, (moduleTypeId, module, data));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(callData, signer.account.rootValidator());

		vm.expectEmit(true, true, true, true);
		emit ModuleInstalled(moduleTypeId, module);

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		vm.assertTrue(IModule(module).isInitialized(address(signer.account)));
	}

	function uninstall(Signer memory signer, ModuleType moduleTypeId, address module, bytes memory data) internal {
		bytes memory callData = abi.encodeCall(Vortex.uninstallModule, (moduleTypeId, module, data));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(callData, signer.account.rootValidator());

		vm.expectEmit(true, true, true, true);
		emit ModuleUninstalled(moduleTypeId, module);

		ENTRYPOINT.handleOps(userOps, signer.eoa);

		vm.assertFalse(IModule(module).isInitialized(address(signer.account)));
	}

	function prepareUserOp(
		Signer memory signer,
		address payable account,
		bytes memory initCode,
		address validator
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		userOp = defaultUserOp(account, VALIDATION_MODE_DEFAULT, validator);
		userOp.initCode = initCode;
		(userOpHash, userOp.signature) = signer.signUserOp(userOp);
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory callData
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		return signer.prepareUserOp(callData, signer.account.rootValidator());
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory callData,
		address validator
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		return signer.prepareUserOp(callData, validator, VALIDATION_MODE_DEFAULT);
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory callData,
		address validator,
		ValidationMode mode
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		userOp = defaultUserOp(address(signer.account), mode, validator);
		userOp.callData = callData;
		(userOpHash, userOp.signature) = signer.signUserOp(userOp);
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory initCode,
		bytes memory callData,
		bytes memory paymasterAndData
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		return signer.prepareUserOp(initCode, callData, paymasterAndData, signer.account.rootValidator());
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory initCode,
		bytes memory callData,
		bytes memory paymasterAndData,
		address validator
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		return signer.prepareUserOp(initCode, callData, paymasterAndData, validator, VALIDATION_MODE_DEFAULT);
	}

	function prepareUserOp(
		Signer memory signer,
		bytes memory initCode,
		bytes memory callData,
		bytes memory paymasterAndData,
		address validator,
		ValidationMode mode
	) internal view returns (PackedUserOperation memory userOp, bytes32 userOpHash) {
		userOp = defaultUserOp(address(signer.account), mode, validator);
		userOp.initCode = initCode;
		userOp.callData = callData;
		userOp.paymasterAndData = paymasterAndData;
		(userOpHash, userOp.signature) = signer.signUserOp(userOp);
	}

	function signUserOp(
		Signer memory signer,
		PackedUserOperation memory userOp
	) internal view returns (bytes32 userOpHash, bytes memory signature) {
		signature = signer.sign((userOpHash = ENTRYPOINT.getUserOpHash(userOp)));
	}

	function sign(Signer memory signer, bytes32 messageHash) internal pure returns (bytes memory signature) {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, messageHash.toEthSignedMessageHash());
		signature = abi.encodePacked(r, s, v);
	}

	function addDeposit(Signer memory signer, uint256 value, address beneficiary) internal {
		vm.assertTrue(value != 0);
		vm.prank(signer.eoa);

		uint256 deposit = ENTRYPOINT.balanceOf(beneficiary);
		ENTRYPOINT.depositTo{value: value}(beneficiary);

		vm.assertEq(ENTRYPOINT.balanceOf(beneficiary), deposit + value);
	}

	function addStake(Signer memory signer, uint256 value, uint32 unstakeDelaySec) internal {
		vm.assertTrue(value != 0 && unstakeDelaySec != 0);
		vm.prank(signer.eoa);

		ENTRYPOINT.addStake{value: value}(unstakeDelaySec);

		IEntryPoint.DepositInfo memory info = ENTRYPOINT.getDepositInfo(signer.eoa);
		vm.assertTrue(info.staked);
		vm.assertGe(info.stake, value);
		vm.assertEq(info.unstakeDelaySec, unstakeDelaySec);
	}

	// nonce: [1 bytes validation mode][3 bytes unused][20 bytes validator][8 bytes nonce]
	function getNonce(address account, ValidationMode mode, address validator) internal view returns (uint256 nonce) {
		vm.assertTrue(mode == VALIDATION_MODE_DEFAULT || mode == VALIDATION_MODE_ENABLE);
		return ENTRYPOINT.getNonce(account, mode.encodeNonceKey(validator));
	}

	// bytes32 salt: [2 bytes id][10 bytes keyword][20 bytes owner]
	function encodeSalt(Signer memory signer, uint16 id) internal pure returns (bytes32 salt) {
		assembly ("memory-safe") {
			salt := or(or(shl(0xf0, id), shr(0x10, mload(add(signer, 0x20)))), shr(0x60, shl(0x60, mload(signer))))
		}
	}

	function defaultUserOp(
		address account,
		ValidationMode mode,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		userOp = PackedUserOperation({
			sender: account,
			nonce: getNonce(account, mode, validator),
			initCode: "",
			callData: "",
			accountGasLimits: defaultGasLimits(),
			preVerificationGas: defaultGas(),
			gasFees: defaultGasFees(),
			paymasterAndData: "",
			signature: ""
		});
	}

	function defaultGas() internal pure returns (uint128) {
		return uint128(1e6);
	}

	function defaultGasLimits() internal pure returns (bytes32) {
		return bytes32(abi.encodePacked(defaultGas(), defaultGas()));
	}

	function defaultGasFees() internal pure returns (bytes32) {
		return bytes32(abi.encodePacked(uint128(1), uint128(1)));
	}
}
