// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHook, IModule, IValidator} from "src/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "src/libraries/MessageHashUtils.sol";
import {SignatureChecker} from "src/libraries/SignatureChecker.sol";
import {ModuleType, ValidationData} from "src/types/DataTypes.sol";
import {ERC7739Validator} from "src/modules/base/ERC7739Validator.sol";

/// @title ECDSAValidator
/// @notice Verifies user operation signatures for smart accounts.
/// @dev Modified from https://github.com/zerodevapp/kernel/blob/dev/src/validator/ECDSAValidator.sol
contract ECDSAValidator is IValidator, IHook, ERC7739Validator {
	using MessageHashUtils for bytes32;
	using SignatureChecker for address;

	/// @notice Thrown when the provided owner is invalid
	error InvalidAccountOwner();

	/// @notice Emitted when the ownership of a smart account is transferred
	event AccountOwnerUpdated(address indexed account, address indexed owner);

	mapping(address account => address owner) internal _accountOwners;

	/// @inheritdoc IModule
	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(data.length == 20, InvalidDataLength());
		_setAccountOwner(_checkAccountOwner(address(bytes20(data))));
	}

	/// @inheritdoc IModule
	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
	}

	/// @inheritdoc IModule
	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	/// @notice Returns the owner of the smart account
	/// @param account The address of the smart account
	/// @return The owner of the smart account
	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	/// @inheritdoc IValidator
	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validationData) {
		bool result = _erc1271IsValidSignatureNowCalldata(userOpHash, _erc1271UnwrapSignature(userOp.signature));

		assembly ("memory-safe") {
			validationData := iszero(result)
		}
	}

	/// @inheritdoc IValidator
	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue) {
		return _erc1271IsValidSignatureWithSender(sender, hash, _erc1271UnwrapSignature(signature));
	}

	/// @inheritdoc IHook
	function preCheck(address msgSender, uint256, bytes calldata) external payable returns (bytes memory context) {
		require(_erc1271CallerIsSafe(msgSender), InvalidAccountOwner());
		return context;
	}

	/// @inheritdoc IHook
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

	/// @inheritdoc IModule
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_HOOK;
	}

	function _validateSignatureForOwner(
		address owner,
		bytes32 hash,
		bytes calldata signature
	) internal view virtual returns (bool) {
		return
			owner.isValidSignatureNowCalldata(hash, signature) ||
			owner.isValidSignatureNowCalldata(hash.toEthSignedMessageHash(), signature);
	}

	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual override returns (bool) {
		return _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature);
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual override returns (bool) {
		return sender == _getAccountOwner(msg.sender);
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
