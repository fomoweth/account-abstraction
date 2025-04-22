// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IValidator} from "src/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "src/libraries/MessageHashUtils.sol";
import {SignatureChecker} from "src/libraries/SignatureChecker.sol";
import {ModuleType, ValidationData} from "src/types/DataTypes.sol";
import {ERC7739Validator} from "src/modules/base/ERC7739Validator.sol";

contract MockValidator is IValidator, ERC7739Validator {
	using MessageHashUtils for bytes32;
	using SignatureChecker for address;

	/// @notice Thrown when the provided owner is invalid
	error InvalidAccountOwner();

	/// @notice Emitted when the ownership of a smart account is transferred
	event AccountOwnerUpdated(address indexed account, address indexed owner);

	mapping(address account => address owner) internal _accountOwners;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(data.length == 20, InvalidDataLength());
		_setAccountOwner(_checkAccountOwner(address(bytes20(data))));
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validation) {
		bool result = _erc1271IsValidSignatureNowCalldata(userOpHash, userOp.signature);

		assembly ("memory-safe") {
			validation := iszero(result)
		}
	}

	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue) {
		return _erc1271IsValidSignatureWithSender(sender, hash, _erc1271UnwrapSignature(signature));
	}

	function transferOwnership(address newOwner) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(newOwner));
	}

	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	function name() external pure returns (string memory) {
		return "MockValidator";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

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
