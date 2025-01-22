// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {Signers} from "test/shared/Signers.sol";

library UserOperationUtils {
	using ECDSA for bytes32;

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	function buildUserOpWithInitCodeAndCalldata(
		Signers.Signer memory signer,
		address account,
		bytes memory initCode,
		bytes memory callData,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		userOp = buildUserOp(account, getNonce(account, validator));
		userOp.initCode = initCode;
		userOp.callData = callData;
		userOp.signature = signUserOp(signer, userOp);
	}

	function buildUserOpWithInitCode(
		Signers.Signer memory signer,
		address account,
		bytes memory initCode,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		userOp = buildUserOp(account, getNonce(account, validator));
		userOp.initCode = initCode;
		userOp.signature = signUserOp(signer, userOp);
	}

	function buildUserOpWithCalldata(
		Signers.Signer memory signer,
		address account,
		bytes memory callData,
		address validator
	) internal view returns (PackedUserOperation memory userOp) {
		userOp = buildUserOp(account, getNonce(account, validator));
		userOp.callData = callData;
		userOp.signature = signUserOp(signer, userOp);
	}

	function buildUserOp(address account, uint256 nonce) internal pure returns (PackedUserOperation memory userOp) {
		userOp = PackedUserOperation({
			sender: account,
			nonce: nonce,
			initCode: emptyBytes(),
			callData: emptyBytes(),
			accountGasLimits: defaultGasLimits(),
			preVerificationGas: defaultGas(),
			gasFees: defaultGasLimits(),
			paymasterAndData: emptyBytes(),
			signature: emptyBytes()
		});
	}

	function getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
		userOp = PackedUserOperation({
			sender: address(0),
			nonce: 0,
			initCode: emptyBytes(),
			callData: emptyBytes(),
			accountGasLimits: defaultGasLimits(),
			preVerificationGas: defaultGas(),
			gasFees: defaultGasLimits(),
			paymasterAndData: emptyBytes(),
			signature: emptyBytes()
		});
	}

	function signUserOp(
		Signers.Signer memory signer,
		PackedUserOperation memory userOp
	) internal view returns (bytes memory signature) {
		bytes32 userOpHash = keccak256(
			abi.encode(
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
			)
		);

		bytes32 messageHash = userOpHash.toEthSignedMessageHash();

		(uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, messageHash);

		return abi.encodePacked(r, s, v);
	}

	function parseValidator(uint256 nonce) internal pure returns (address validator) {
		assembly ("memory-safe") {
			validator := shr(0x60, shl(0x20, nonce))
		}
	}

	function isModuleEnableMode(uint256 nonce) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := eq(shl(0xf8, byte(0x03, nonce)), 0x01)
		}
	}

	function getNonce(address account, address validator) internal view returns (uint256 nonce) {
		return getNonce(account, bytes1(0x00), validator, bytes3(0x00));
	}

	function getNonce(
		address account,
		bytes1 mode,
		address validator,
		bytes3 batchId
	) internal view returns (uint256 nonce) {
		uint192 key = encodeNonceKey(mode, validator, batchId);
		return ENTRYPOINT.getNonce(account, key);
	}

	function encodeNonceKey(bytes1 mode, address validator, bytes3 batchId) internal pure returns (uint192 key) {
		assembly ("memory-safe") {
			key := or(shr(88, mode), validator)
			key := or(shr(64, batchId), key)
		}
	}

	function defaultGas() internal pure returns (uint128) {
		return uint128(2e6);
	}

	function defaultGasLimits() internal pure returns (bytes32) {
		return bytes32(abi.encodePacked(defaultGas(), defaultGas()));
	}

	function emptyBytes() internal pure returns (bytes calldata data) {
		assembly ("memory-safe") {
			data.offset := 0x00
			data.length := 0x00
		}
	}
}
