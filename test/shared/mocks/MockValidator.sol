// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {ValidationData} from "src/types/Types.sol";
import {ERC1271} from "src/utils/ERC1271.sol";
import {HybridValidatorBase} from "src/modules/validators/HybridValidatorBase.sol";

contract MockValidator is HybridValidatorBase, ERC1271 {
	using BytesLib for bytes;
	using SignatureCheckerLib for address;
	using SignatureCheckerLib for bytes32;

	mapping(address account => address owner) internal _accountOwners;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(data.toAddress(0)));
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
	}

	function transferOwnership(address owner) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(owner));
	}

	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	function isAccountOwner(address account, address owner) external view returns (bool) {
		return _getAccountOwner(account) == owner;
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validation) {
		bool isValid = _validateSignatureForOwner(_getAccountOwner(msg.sender), userOpHash, userOp.signature);

		assembly ("memory-safe") {
			validation := iszero(isValid)
		}
	}

	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view virtual returns (bytes4 sigValidationResult) {
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
		return "MockValidator";
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
		return super._erc1271CallerIsSafe(sender);
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
