// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IValidator} from "src/interfaces/IERC7579Modules.sol";
import {IERC7579Account} from "src/interfaces/IERC7579Account.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {EIP712} from "src/utils/EIP712.sol";
import {ERC1271} from "src/utils/ERC1271.sol";
import {ValidationMode, BatchId} from "src/types/ValidationMode.sol";
import {ModuleBase} from "../ModuleBase.sol";

/// @title ValidatorBase

abstract contract ValidatorBase is IValidator, ModuleBase, ERC1271 {
	using AccountIdLib for string;
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;

	uint256 internal constant VALIDATION_SUCCESS = 0;
	uint256 internal constant VALIDATION_FAILED = 1;

	bytes1 internal constant MODE_VALIDATION = 0x00;
	bytes1 internal constant MODE_MODULE_ENABLE = 0x01;
	bytes3 internal constant MODE_BATCH_ID_DEFAULT = 0x00;

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (uint256 validation) {
		bool isValid = _erc1271IsValidSignatureNowCalldata(userOpHash, _erc1271UnwrapSignature(userOp.signature));

		assembly ("memory-safe") {
			validation := iszero(isValid)
		}
	}

	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view virtual returns (bytes4 magicValue) {
		return _erc1271IsValidSignatureWithSender(sender, hash, _erc1271UnwrapSignature(signature));
	}

	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool isValid) {
		if (data.length < 20) InvalidDataLength.selector.revertWith();
		return _validateSignatureForOwner(data.decodeAddress(), hash, signature);
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual override returns (bool flag) {
		assembly ("memory-safe") {
			flag := or(eq(sender, caller()), eq(sender, MULTICALLER_WITH_SIGNER))
		}
	}

	function eip712Domain()
		public
		view
		virtual
		override
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainId,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		)
	{
		(name, version) = IERC7579Account(msg.sender).accountId().parseAccountId();

		assembly ("memory-safe") {
			fields := 0x0f
			chainId := chainid()
			verifyingContract := caller()
			pop(salt)
			pop(extensions)
		}
	}

	function _hashTypedData(bytes32 structHash) internal view virtual override returns (bytes32 digest) {
		(, string memory name, string memory version, uint256 chainId, address verifyingContract, , ) = eip712Domain();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, DOMAIN_TYPEHASH)
			mstore(add(ptr, 0x20), keccak256(add(name, 0x20), mload(name)))
			mstore(add(ptr, 0x40), keccak256(add(version, 0x20), mload(version)))
			mstore(add(ptr, 0x60), chainId)
			mstore(add(ptr, 0x80), verifyingContract)
			digest := keccak256(ptr, 0xa0) // domain separator

			mstore(0x00, 0x1901000000000000)
			mstore(0x1a, digest)
			mstore(0x3a, structHash)
			digest := keccak256(0x18, 0x42) // hash typed data

			mstore(0x3a, 0x00)
		}
	}

	function isModuleType(uint256 moduleTypeId) external pure virtual returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR;
	}
}
