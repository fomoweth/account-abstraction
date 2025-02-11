// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IEntryPoint, PackedUserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";
import {Calldata} from "src/libraries/Calldata.sol";
import {Math} from "src/libraries/Math.sol";
import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_STATIC, CALLTYPE_DELEGATE, EXECTYPE_DEFAULT, EXECTYPE_TRY} from "src/types/Constants.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";

struct User {
	address payable addr;
	uint256 publicKeyX;
	uint256 publicKeyY;
	uint256 privateKey;
}

using UserHelper for User global;

library UserHelper {
	using ECDSA for bytes32;

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	bytes4 internal constant EXECUTE_USER_OP_SELECTOR = 0x8dd7712f;
	bytes4 internal constant EXECUTE_SELECTOR = 0xe9ae5c53;
	bytes4 internal constant EXECUTE_FROM_EXECUTOR_SELECTOR = 0xd691c964;

	bytes4 internal constant INSTALL_MODULE_SELECTOR = 0x9517e29f;
	bytes4 internal constant UNINSTALL_MODULE_SELECTOR = 0xa71763a8;

	function handleOps(
		User memory user,
		PackedUserOperation[] memory userOps,
		address payable beneficiary
	) internal returns (uint256 gasUsed) {
		vm.prank(user.addr);
		gasUsed = gasleft();
		ENTRYPOINT.handleOps(userOps, beneficiary);
		gasUsed -= gasleft();
	}

	function buildUserOps(
		User memory user,
		address account,
		ExecType execType,
		Execution[] memory executions,
		address validator
	) internal view returns (PackedUserOperation[] memory userOps) {
		require(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		userOps = new PackedUserOperation[](1);
		userOps[0] = defaultUserOp(account, getNonce(account, validator));
		userOps[0].callData = prepareExecutionCalldata(execType, executions);
		userOps[0].signature = signUserOp(user, userOps[0]);
	}

	function buildUserOp(
		User memory user,
		address account,
		ExecType execType,
		Execution[] memory executions,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		require(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		userOp = defaultUserOp(account, getNonce(account, validator));
		userOp.callData = prepareExecutionCalldata(execType, executions);
		userOp.signature = signUserOp(user, userOp);
	}

	function buildUserOp(
		User memory user,
		address account,
		bytes memory initCode,
		bytes memory callData,
		bytes memory paymasterAndData,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		userOp = defaultUserOp(account, getNonce(account, validator));
		userOp.initCode = initCode;
		userOp.callData = callData;
		userOp.paymasterAndData = paymasterAndData;
		userOp.signature = signUserOp(user, userOp);
	}

	function defaultUserOp(address account, uint256 nonce) internal pure returns (PackedUserOperation memory userOp) {
		userOp = PackedUserOperation({
			sender: account,
			nonce: nonce,
			initCode: Calldata.emptyBytes(),
			callData: Calldata.emptyBytes(),
			accountGasLimits: defaultGasLimits(),
			preVerificationGas: defaultGas(),
			gasFees: defaultGasLimits(),
			paymasterAndData: Calldata.emptyBytes(),
			signature: Calldata.emptyBytes()
		});
	}

	function signUserOp(
		User memory user,
		PackedUserOperation memory userOp
	) internal view returns (bytes memory signature) {
		// bytes32 userOpHash = hash(userOp);
		bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
		bytes32 messageHash = userOpHash.toEthSignedMessageHash();
		return sign(user, messageHash);
	}

	function sign(User memory user, bytes32 digest) internal pure returns (bytes memory signature) {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);
		signature = abi.encodePacked(r, s, v);
	}

	function hash(PackedUserOperation memory userOp) internal view returns (bytes32) {
		return keccak256(encode(userOp));
	}

	function encode(PackedUserOperation memory userOp) internal view returns (bytes memory data) {
		data = abi.encode(
			keccak256(
				abi.encode(
					userOp.sender,
					userOp.nonce,
					keccak256(userOp.initCode),
					keccak256(userOp.callData),
					userOp.accountGasLimits,
					userOp.preVerificationGas,
					userOp.gasFees,
					keccak256(userOp.paymasterAndData)
				)
			),
			ENTRYPOINT,
			block.chainid
		);
	}

	function prepareExecutionCalldata(
		ExecType execType,
		Execution[] memory executions
	) internal pure returns (bytes memory executionCalldata) {
		uint256 length = executions.length;
		require(length != 0);

		if (length == 1) {
			executionCalldata = prepareExecutionCalldata(
				execType,
				executions[0].target,
				executions[0].value,
				executions[0].callData
			);
		} else {
			ExecutionMode mode = (execType == EXECTYPE_DEFAULT)
				? ExecutionModeLib.encodeBatch()
				: ExecutionModeLib.encodeTryBatch();

			executionCalldata = abi.encodeCall(IERC7579Account.execute, (mode, abi.encode(executions)));
		}
	}

	function prepareExecutionCalldata(
		ExecType execType,
		address target,
		uint256 value,
		bytes memory callData
	) internal pure returns (bytes memory executionCalldata) {
		ExecutionMode mode = (execType == EXECTYPE_DEFAULT)
			? ExecutionModeLib.encodeSingle()
			: ExecutionModeLib.encodeTrySingle();

		executionCalldata = abi.encodeCall(IERC7579Account.execute, (mode, abi.encodePacked(target, value, callData)));
	}

	function toExecutions(
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calls
	) internal pure returns (Execution[] memory executions) {
		uint256 length = targets.length;
		require(length == values.length && length == calls.length);

		executions = new Execution[](length);
		for (uint256 i; i < targets.length; ++i) {
			executions[i] = Execution({target: targets[i], value: values[i], callData: calls[i]});
		}
	}

	function parseValidator(uint256 nonce) internal pure returns (address validator) {
		assembly ("memory-safe") {
			validator := shr(0x60, nonce)
		}
	}

	function getNonce(address account, address validator) internal view returns (uint256 nonce) {
		uint192 key = uint192(bytes24(bytes20(validator)));
		return ENTRYPOINT.getNonce(account, key);
	}

	function encodeNonceKey(address validator) internal pure returns (uint192 key) {
		assembly ("memory-safe") {
			key := shl(0x60, validator)
		}
	}

	function resetNonce(User memory user) internal returns (uint64) {
		vm.resetNonce(user.addr);
		return vm.getNonce(user.addr);
	}

	function setNonce(User memory user, uint64 nonce) internal returns (uint64) {
		uint64 current = vm.getNonce(user.addr);
		if (nonce == current) return nonce;

		if (nonce > current) vm.setNonce(user.addr, nonce);
		else vm.setNonceUnsafe(user.addr, nonce);

		return vm.getNonce(user.addr);
	}

	function getNonce(User memory user) internal view returns (uint64 nonce) {
		return vm.getNonce(user.addr);
	}

	function defaultGas() internal pure returns (uint128) {
		return uint128(3e6);
	}

	function defaultGasLimits() internal pure returns (bytes32) {
		return bytes32(abi.encodePacked(defaultGas(), defaultGas()));
	}

	function defaultGasFees() internal pure returns (bytes32) {
		return bytes32(abi.encodePacked(uint128(1), uint128(1)));
	}
}
