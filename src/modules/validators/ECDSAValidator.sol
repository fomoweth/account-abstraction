// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IValidator, IHook} from "src/interfaces/IERC7579Modules.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "src/types/Constants.sol";
import {ModuleType, ValidationData} from "src/types/Types.sol";
import {ModuleBase} from "src/modules/base/ModuleBase.sol";

/// @title ECDSAValidator

contract ECDSAValidator is IValidator, IHook, ModuleBase {
	using ECDSA for bytes32;

	/// @notice Thrown when the provided owner is invalid
	error InvalidAccountOwner();

	/// @notice Emitted when the ownership of a smart account is transferred
	event AccountOwnerUpdated(address indexed account, address indexed owner);

	mapping(address account => address owner) internal _accountOwners;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	/// @notice Initialize the module with the given data
	/// @param data The data to initialize the module with
	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(data.length == 20, InvalidDataLength());
		_setAccountOwner(_checkAccountOwner(address(bytes20(data))));
	}

	/// @notice De-initialize the module with the given data
	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
	}

	/// @notice Check if the module is initialized for the given smart account
	/// @param account The address of the smart account
	/// @return True if the module is initialized, false otherwise
	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	/// @notice Returns the owner of the smart account
	/// @param account The address of the smart account
	/// @return The owner of the smart account
	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	/// @notice Validates user operation
	/// @param userOp The PackedUserOperation to be validated
	/// @param userOpHash The hash of the PackedUserOperation to be validated
	/// @return validationData The result of the signature validation
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validationData) {
		// bool result = _validateSignatureForOwner(_getAccountOwner(msg.sender), userOpHash, userOp.signature);

		// assembly ("memory-safe") {
		// 	validationData := iszero(result)
		// }

		validationData = _validateSignatureForOwner(_getAccountOwner(msg.sender), userOpHash, userOp.signature)
			? VALIDATION_SUCCESS
			: VALIDATION_FAILED;
	}

	/// @notice Validates a signature using ERC-1271
	/// @param hash The hash of the message
	/// @param signature The signature of the message
	/// @return magicValue The ERC-1271 `MAGIC_VALUE` if the signature is valid
	function isValidSignatureWithSender(
		address,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue) {
		// bool result = _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature);

		// assembly ("memory-safe") {
		// 	// `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
		// 	// We use `0xffffffff` for invalid, in convention with the reference implementation.
		// 	magicValue := shl(0xe0, or(0x1626ba7e, sub(0x00, iszero(result))))
		// }

		magicValue = _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature)
			? ERC1271_SUCCESS
			: ERC1271_FAILED;
	}

	function preCheck(address msgSender, uint256, bytes calldata) external payable returns (bytes memory context) {
		require(msgSender == _getAccountOwner(msg.sender), InvalidAccountOwner());
		return context;
	}

	function postCheck(bytes calldata context) external payable {}

	/// @notice Returns the name of the module
	/// @return The name of the module
	function name() external pure returns (string memory) {
		return "ECDSAValidator";
	}

	/// @notice Returns the version of the module
	/// @return The version of the module
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	/// @notice Checks if the module is of the specified type
	/// @param moduleTypeId The module type ID to check
	/// @return True if the module is of the specified type, false otherwise
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_HOOK;
	}

	function _validateSignatureForOwner(
		address owner,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool) {
		return
			owner == hash.tryRecoverCalldata(signature) ||
			owner == hash.toEthSignedMessageHash().tryRecoverCalldata(signature);
	}

	function _setAccountOwner(address newOwner) internal virtual {
		_accountOwners[msg.sender] = newOwner;
		emit AccountOwnerUpdated(msg.sender, newOwner);
	}

	function _getAccountOwner(address account) internal view virtual returns (address) {
		return _accountOwners[account];
	}

	function _checkAccountOwner(address newOwner) internal view virtual returns (address) {
		assembly ("memory-safe") {
			newOwner := shr(0x60, shl(0x60, newOwner))
			if or(iszero(newOwner), iszero(iszero(extcodesize(newOwner)))) {
				mstore(0x00, 0x36b1fa3a) // InvalidAccountOwner()
				revert(0x1c, 0x04)
			}
		}

		return newOwner;
	}

	function _isInitialized(address account) internal view virtual returns (bool) {
		return _getAccountOwner(account) != address(0);
	}
}
