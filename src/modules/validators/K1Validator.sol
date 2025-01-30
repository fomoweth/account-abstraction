// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {EnumerableSet4337} from "src/libraries/EnumerableSet4337.sol";
import {ERC1271} from "src/utils/ERC1271.sol";
import {ValidatorBase} from "./ValidatorBase.sol";

/// @title K1Validator
/// @notice Verifies user operation signatures for smart accounts
/// @dev Modified from https://github.com/erc7579/erc7739Validator/blob/main/src/SampleK1ValidatorWithERC7739.sol

contract K1Validator is ValidatorBase, ERC1271 {
	using BytesLib for bytes;
	using CustomRevert for bytes4;
	using ECDSA for bytes32;
	using EnumerableSet4337 for EnumerableSet4337.AddressSet;
	using SignatureCheckerLib for address;

	error AuthorizationFailed();
	error InvalidSender();
	error SenderAlreadyExists(address sender);
	error SenderNotExists(address sender);

	mapping(address account => address owner) internal _accountOwners;

	EnumerableSet4337.AddressSet private _authorizedSenders;

	function onInstall(bytes calldata data) external payable {
		if (_isInitialized(msg.sender)) AlreadyInitialized.selector.revertWith(msg.sender);

		_setAccountOwner(data.toAddress(0));
		if (data.length > 96) _authorizeSenders(data.toAddressArray(1));
	}

	function onUninstall(bytes calldata) external payable {
		if (!_isInitialized(msg.sender)) NotInitialized.selector.revertWith(msg.sender);

		delete _accountOwners[msg.sender];
		_authorizedSenders.removeAll(msg.sender);
	}

	function transferOwnership(address newOwner) external {
		if (!_isInitialized(msg.sender)) NotInitialized.selector.revertWith(msg.sender);

		_setAccountOwner(newOwner);
	}

	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	function addAuthorizedSender(address sender) external {
		_addAuthorizedSender(sender);
	}

	function removeAuthorizedSender(address sender) external {
		if (!_authorizedSenders.remove(msg.sender, sender)) AuthorizationFailed.selector.revertWith();
	}

	function getAuthorizedSenders(address account) external view returns (address[] memory senders) {
		return _authorizedSenders.values(account);
	}

	function isAuthorizedSender(address account, address sender) public view returns (bool) {
		return _authorizedSenders.contains(account, sender);
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (uint256 validation) {
		bool isValid = _validateSignatureForOwner(_getAccountOwner(msg.sender), userOpHash, userOp.signature);

		assembly ("memory-safe") {
			validation := iszero(isValid)
		}
	}

	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue) {
		return _erc1271IsValidSignatureWithSender(sender, hash, _erc1271UnwrapSignature(signature));
	}

	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool isValid) {
		return _validateSignatureForOwner(data.toAddress(), hash, signature);
	}

	function name() external pure virtual override returns (string memory) {
		return "K1Validator";
	}

	function version() external pure virtual override returns (string memory) {
		return "1.0.0";
	}

	function _isInitialized(address account) internal view virtual override returns (bool) {
		return _getAccountOwner(account) != address(0);
	}

	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual override returns (bool) {
		return _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature);
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual override returns (bool flag) {
		return super._erc1271CallerIsSafe(sender) || _authorizedSenders.contains(msg.sender, sender);
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

	function _authorizeSenders(address[] calldata senders) internal virtual {
		uint256 length = senders.length;
		for (uint256 i; i < length; ) {
			_addAuthorizedSender(senders[i]);

			unchecked {
				i = i + 1;
			}
		}
	}

	function _addAuthorizedSender(address sender) internal virtual {
		if (sender == address(0)) InvalidSender.selector.revertWith();
		if (!_authorizedSenders.add(msg.sender, sender)) AuthorizationFailed.selector.revertWith();
	}

	function _setAccountOwner(address newOwner) internal virtual {
		assembly ("memory-safe") {
			newOwner := shr(0x60, shl(0x60, newOwner))
			if or(iszero(newOwner), iszero(iszero(extcodesize(newOwner)))) {
				mstore(0x00, 0x54a56786) // InvalidNewOwner()
				revert(0x1c, 0x04)
			}

			mstore(0x00, shr(0x60, shl(0x60, caller())))
			mstore(0x20, _accountOwners.slot)
			sstore(keccak256(0x00, 0x40), newOwner)
		}
	}

	function _getAccountOwner(address account) internal view virtual returns (address owner) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, account)))
			mstore(0x20, _accountOwners.slot)
			owner := sload(keccak256(0x00, 0x40))
		}
	}
}
