// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModule, IStatelessValidator, IValidator} from "src/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {EnumerableSet4337} from "src/libraries/EnumerableSet4337.sol";
import {MessageHashUtils} from "src/libraries/MessageHashUtils.sol";
import {SignatureChecker} from "src/libraries/SignatureChecker.sol";
import {ModuleType, ValidationData} from "src/types/DataTypes.sol";
import {ERC7739Validator} from "src/modules/base/ERC7739Validator.sol";

/// @title K1Validator
/// @notice Verifies user operation signatures for smart accounts
/// @dev Modified from https://github.com/erc7579/erc7739Validator/blob/main/src/SampleK1ValidatorWithERC7739.sol
contract K1Validator is IValidator, IStatelessValidator, ERC7739Validator {
	using EnumerableSet4337 for EnumerableSet4337.AddressSet;
	using MessageHashUtils for bytes32;
	using SignatureChecker for address;

	/// @notice Thrown when the provided owner is invalid
	error InvalidAccountOwner();

	/// @notice Thrown when the provided sender is invalid
	error InvalidSender();

	/// @notice Thrown when trying to add a sender that already exists from the set
	error AlreadyAuthorized(address sender);

	/// @notice Thrown when trying to remove a sender that doesn't exist from the set
	error NotAuthorized(address sender);

	/// @notice Emitted when the ownership of a smart account is transferred
	event AccountOwnerUpdated(address indexed account, address indexed owner);

	mapping(address account => address owner) internal _accountOwners;

	EnumerableSet4337.AddressSet private _authorizedSenders;

	/// @inheritdoc IModule
	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(_checkSendersLength(data), InvalidDataLength());
		_setAccountOwner(_checkAccountOwner(address(bytes20(data))));
		while ((data = data[20:]).length != 0) _authorize(address(bytes20(data)));
	}

	/// @inheritdoc IModule
	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
		_authorizedSenders.removeAll(msg.sender);
	}

	/// @inheritdoc IModule
	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
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

	/// @inheritdoc IStatelessValidator
	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool) {
		require(data.length == 20, InvalidDataLength());
		return _validateSignatureForOwner(address(bytes20(data)), hash, signature);
	}

	/// @notice Transfers ownership of the validator to a new owner
	/// @param newOwner The address of the new owner
	function transferOwnership(address newOwner) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(newOwner));
	}

	/// @notice Returns the owner of the smart account
	/// @param account The address of the smart account
	/// @return The owner of the smart account
	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	/// @notice Adds a sender to the _authorizedSenders list for the smart account
	/// @param sender The address of the sender to be added to the _authorizedSenders list
	function authorize(address sender) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_authorize(sender);
	}

	/// @notice Removes a sender from the _authorizedSenders list for the smart account
	/// @param sender The address of the sender to be removed from the _authorizedSenders list
	function revoke(address sender) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		require(_authorizedSenders.remove(msg.sender, sender), NotAuthorized(sender));
	}

	/// @notice Checks if a sender is in the _authorizedSenders list for the smart account
	/// @param account The address of the smart account
	/// @param sender The address of the sender
	/// @return True if the sender is in the _authorizedSenders list, false otherwise
	function isAuthorized(address account, address sender) public view virtual returns (bool) {
		return _authorizedSenders.contains(account, sender);
	}

	/// @notice Returns the list of sender addresses authorized by the given smart account
	/// @param account The address of the smart account
	/// @return senders The list of authorized sender addresses
	function getAuthorizedSenders(address account) external view returns (address[] memory senders) {
		return _authorizedSenders.values(account);
	}

	/// @notice Returns the name of the module
	/// @return The name of the module
	function name() external pure returns (string memory) {
		return "K1Validator";
	}

	/// @notice Returns the version of the module
	/// @return The version of the module
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	/// @inheritdoc IModule
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR;
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
		return super._erc1271CallerIsSafe(sender) || isAuthorized(msg.sender, sender);
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

	function _authorize(address sender) internal virtual {
		require(sender != address(0), InvalidSender());
		require(_authorizedSenders.add(msg.sender, sender), AlreadyAuthorized(sender));
	}

	function _isInitialized(address account) internal view virtual returns (bool) {
		return _getAccountOwner(account) != address(0);
	}

	function _checkSendersLength(bytes calldata data) internal pure virtual returns (bool result) {
		assembly ("memory-safe") {
			if iszero(lt(data.length, 0x14)) {
				let quotient := shr(0x40, mul(data.length, 0xCCCCCCCCCCCCD00))
				let remainder := sub(data.length, mul(quotient, 0x14))
				result := iszero(remainder)
			}
		}
	}
}
