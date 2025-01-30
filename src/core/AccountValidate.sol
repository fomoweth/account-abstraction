// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IHook, IValidator} from "src/interfaces/IERC7579Modules.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {ModuleLib} from "src/libraries/ModuleLib.sol";
import {EIP712} from "src/utils/EIP712.sol";
import {CallType} from "src/types/ExecutionMode.sol";
import {SentinelList} from "src/types/SentinelList.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";
import {AccountBase} from "./AccountBase.sol";
import {AccountModule} from "./AccountModule.sol";

/// @title AccountValidate

abstract contract AccountValidate is AccountBase, AccountModule, EIP712, RegistryAdapter {
	using BytesLib for bytes;
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;
	using ModuleLib for address;

	/// @dev keccak256(bytes("ModuleEnableMode(address module,uint256 moduleType,bytes32 userOpHash,bytes32 initDataHash)"));
	bytes32 internal constant MODULE_ENABLE_MODE_TYPE_HASH =
		0xbe844ccefa05559a48680cb7fe805b2ec58df122784191aed18f9f315c763e1b;

	bytes32 internal constant ENABLE_TYPE_HASH = 0xb17ab1224aca0d4255ef8161acaf2ac121b8faa32a4b2258c912cc5f8308c505;

	bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

	bytes4 internal constant ERC7739_SUPPORTS = 0x77390000;
	bytes4 internal constant ERC7739_SUPPORTS_V1 = 0x77390001;

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	function checkERC7739Support(
		bytes32 hash,
		bytes calldata signature
	) public view virtual returns (bytes4 validationSig) {
		unchecked {
			SentinelList storage validators = ModuleLib.getValidatorsList();
			address cursor = validators.entries[SENTINEL];

			while (cursor != ZERO && cursor != SENTINEL) {
				bytes4 support = IValidator(cursor).isValidSignatureWithSender(msg.sender, hash, signature);
				if (bytes2(support) == bytes2(ERC7739_SUPPORTS) && support > validationSig) {
					validationSig = support;
				}

				cursor = validators.getNext(cursor);
			}

			if (validationSig == bytes4(0)) validationSig = EIP1271_FAILED;
		}
	}

	function _enableMode(
		bytes32 userOpHash,
		bytes calldata data
	) internal virtual withHook returns (bytes calldata userOpSignature) {
		address module;
		uint256 moduleTypeId;
		bytes calldata initData;
		bytes calldata signature;
		(module, moduleTypeId, initData, signature, userOpSignature) = data.decodeEnableMode();

		bytes32 structHash = _buildEnableModeHash(module, moduleTypeId, userOpHash, initData);
		_checkEnableModeSignature(_hashTypedData(structHash), signature.toAddress(), signature);

		_installModule(moduleTypeId, module, initData);
	}

	function _validateUserOp(
		address validator,
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) internal virtual onlyValidatorModule(validator) returns (uint256) {
		if (_isModuleEnableMode(userOp.nonce)) {
			PackedUserOperation memory op = userOp;
			op.signature = _enableMode(userOpHash, userOp.signature);
			return IValidator(validator).validateUserOp(op, userOpHash);
		} else {
			return IValidator(validator).validateUserOp(userOp, userOpHash);
		}
	}

	function _isValidSignature(
		address validator,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual onlyValidatorModule(validator) returns (bytes4) {
		try IValidator(validator).isValidSignatureWithSender(msg.sender, hash, signature) returns (bytes4 res) {
			return res;
		} catch {
			return EIP1271_FAILED;
		}
	}

	function _parseValidator(uint256 nonce) internal pure virtual returns (address validator) {
		assembly ("memory-safe") {
			validator := shr(0x60, shl(0x20, nonce))
		}
	}

	function _isModuleEnableMode(uint256 nonce) internal pure virtual returns (bool flag) {
		assembly ("memory-safe") {
			// MODE_VALIDATION: 0x00
			// MODE_MODULE_ENABLE: 0x01
			flag := eq(byte(0x03, nonce), 0x01)
		}
	}

	function _checkEnableModeSignature(
		bytes32 digest,
		address validator,
		bytes calldata signature
	) internal view virtual {
		assembly ("memory-safe") {
			signature.offset := add(signature.offset, 0x14)
			signature.length := sub(signature.length, 0x14)

			let ptr := mload(0x40)

			mstore(ptr, 0xf551e2ee00000000000000000000000000000000000000000000000000000000) // isValidSignatureWithSender(address,bytes32,bytes)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, address())))
			mstore(add(ptr, 0x24), digest)
			calldatacopy(add(ptr, 0x44), signature.offset, signature.length)

			if iszero(
				and(
					eq(mload(0x00), EIP1271_SUCCESS),
					staticcall(gas(), validator, ptr, add(signature.length, 0x44), 0x00, 0x20)
				)
			) {
				mstore(0x00, 0x82b3d6e5) // InvalidEnableModeSignature()
				revert(0x1c, 0x04)
			}
		}
	}

	function _buildEnableModeHash(
		address module,
		uint256 moduleTypeId,
		bytes32 userOpHash,
		bytes calldata data
	) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, MODULE_ENABLE_MODE_TYPE_HASH)
			mstore(add(ptr, 0x20), shr(0x60, shl(0x60, module)))
			mstore(add(ptr, 0x40), moduleTypeId)
			mstore(add(ptr, 0x60), userOpHash)
			calldatacopy(add(ptr, 0x80), data.offset, data.length)
			mstore(add(ptr, 0x80), keccak256(add(ptr, 0x80), data.length))

			digest := keccak256(ptr, 0xa0)
		}
	}
}
