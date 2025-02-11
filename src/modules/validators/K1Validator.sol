// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IK1Validator} from "src/interfaces/modules/IK1Validator.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {EnumerableSet4337} from "src/libraries/EnumerableSet4337.sol";
import {ERC1271} from "src/utils/ERC1271.sol";
import {HybridValidatorBase} from "./HybridValidatorBase.sol";

/// @title K1Validator
/// @notice Verifies user operation signatures for smart accounts
/// @dev Modified from https://github.com/erc7579/erc7739Validator/blob/main/src/SampleK1ValidatorWithERC7739.sol

contract K1Validator is IK1Validator, HybridValidatorBase, ERC1271 {
	using BytesLib for bytes;
	using EnumerableSet4337 for EnumerableSet4337.AddressSet;
	using SignatureCheckerLib for address;
	using SignatureCheckerLib for bytes32;

	mapping(address account => address owner) internal _accountOwners;

	EnumerableSet4337.AddressSet private _safeSenders;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));

		_setAccountOwner(_checkAccountOwner(data.toAddress(0)));
		if (data.length > 96) _fillSafeSenders(data.toAddressArray(1));
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));

		_safeSenders.removeAll(msg.sender);
		_setAccountOwner(ZERO);
	}

	function transferOwnership(address owner) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(owner));
	}

	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	function addSafeSender(address sender) external {
		_addSafeSender(sender);
	}

	function removeSafeSender(address sender) external {
		require(_safeSenders.remove(msg.sender, sender), SenderNotExists(sender));
	}

	function getSafeSenders(address account) external view returns (address[] memory senders) {
		return _safeSenders.values(account);
	}

	function isSafeSender(address account, address sender) public view returns (bool) {
		return _safeSenders.contains(account, sender);
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
	) external view returns (bool) {
		return _validateSignatureForOwner(data.toAddress(), hash, signature);
	}

	function name() external pure virtual override returns (string memory) {
		return "K1Validator";
	}

	function version() external pure virtual override returns (string memory) {
		return "1.0.0";
	}

	function _isInitialized(address account) internal view virtual override returns (bool) {
		return _getAccountOwner(account) != ZERO;
	}

	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual override returns (bool) {
		return _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature);
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual override returns (bool flag) {
		return super._erc1271CallerIsSafe(sender) || _safeSenders.contains(msg.sender, sender);
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

	function _fillSafeSenders(address[] calldata senders) internal virtual {
		uint256 length = senders.length;
		for (uint256 i; i < length; ) {
			_addSafeSender(senders[i]);

			unchecked {
				i = i + 1;
			}
		}
	}

	function _addSafeSender(address sender) internal virtual {
		require(sender != ZERO, InvalidSender());
		require(_safeSenders.add(msg.sender, sender), SenderAlreadyExists(sender));
	}

	function _setAccountOwner(address owner) internal virtual {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))
			mstore(0x20, _accountOwners.slot)
			sstore(keccak256(0x00, 0x40), owner)
		}
	}

	function _getAccountOwner(address account) internal view virtual returns (address owner) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, account)))
			mstore(0x20, _accountOwners.slot)
			owner := sload(keccak256(0x00, 0x40))
		}
	}

	function _checkAccountOwner(address owner) internal view virtual returns (address) {
		assembly ("memory-safe") {
			owner := shr(0x60, shl(0x60, owner))
			if or(iszero(owner), iszero(iszero(extcodesize(owner)))) {
				mstore(0x00, 0x36b1fa3a) // InvalidAccountOwner()
				revert(0x1c, 0x04)
			}
		}

		return owner;
	}
}
