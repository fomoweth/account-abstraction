// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {EnumerableSet4337} from "src/libraries/EnumerableSet4337.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {ModuleType, ValidationData} from "src/types/Types.sol";
import {ERC7739Validator} from "src/modules/base/ERC7739Validator.sol";

/// @title K1Validator
/// @notice Verifies user operation signatures for smart accounts
/// @dev Modified from https://github.com/erc7579/erc7739Validator/blob/main/src/SampleK1ValidatorWithERC7739.sol

contract K1Validator is ERC7739Validator {
	using BytesLib for *;
	using EnumerableSet4337 for EnumerableSet4337.AddressSet;

	error AlreadyAuthorized(address sender);
	error NotAuthorized(address sender);
	error InvalidSender();

	event Authorized(address indexed account, address indexed sender);
	event Revoked(address indexed account, address indexed sender);

	/// @dev keccak256("AccountOwnerUpdated(address,address)")
	bytes32 private constant ACCOUNT_OWNER_UPDATED_TOPIC =
		0xd85ce777a3f61727a3501a1f3adbbfc9927b5c64326149ba64310037f50bf519;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.validator.accountOwners")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant ACCOUNT_OWNERS_STORAGE_SLOT =
		0x73f50bba1b2b0fd39f326a5de0b3922b4fad09d862eedad31aff9d520dc29a00;

	EnumerableSet4337.AddressSet private _authorizedSenders;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(_checkDataLength(data), InvalidDataLength());
		_setAccountOwner(_checkAccountOwner(data.toAddress()));
		if (data.length > 20) _authorizeSenders(data[20:]);
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(address(0));
		_authorizedSenders.removeAll(msg.sender);
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function transferOwnership(address newOwner) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountOwner(_checkAccountOwner(newOwner));
	}

	function getAccountOwner(address account) external view returns (address) {
		return _getAccountOwner(account);
	}

	function authorizeSender(address sender) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_authorizeSender(sender);
	}

	function revokeSender(address sender) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		require(_authorizedSenders.remove(msg.sender, sender), NotAuthorized(sender));
		emit Revoked(msg.sender, sender);
	}

	function getAuthorizedSenders(address account) external view returns (address[] memory senders) {
		return _authorizedSenders.values(account);
	}

	function isAuthorizedSender(address account, address sender) public view returns (bool) {
		return _authorizedSenders.contains(account, sender);
	}

	function isValidSignatureWithSender(
		address sender,
		bytes32 hash,
		bytes calldata signature
	) external view returns (bytes4 magicValue) {
		return _erc1271IsValidSignatureWithSender(sender, hash, _erc1271UnwrapSignature(signature));
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash
	) external payable returns (ValidationData validationData) {
		bool result = _validateSignatureForOwner(_getAccountOwner(msg.sender), userOpHash, userOp.signature);

		assembly ("memory-safe") {
			validationData := iszero(result)
		}
	}

	function validateSignatureWithData(
		bytes32 hash,
		bytes calldata signature,
		bytes calldata data
	) external view returns (bool) {
		require(data.length == 20, InvalidDataLength());
		return _validateSignatureForOwner(data.toAddress(), hash, signature);
	}

	function name() external pure returns (string memory) {
		return "K1Validator";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_VALIDATOR || moduleTypeId == TYPE_STATELESS_VALIDATOR;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _getAccountOwner(account) != address(0);
	}

	function _erc1271IsValidSignatureNowCalldata(
		bytes32 hash,
		bytes calldata signature
	) internal view virtual override returns (bool) {
		return _validateSignatureForOwner(_getAccountOwner(msg.sender), hash, signature);
	}

	function _erc1271CallerIsSafe(address sender) internal view virtual override returns (bool) {
		return super._erc1271CallerIsSafe(sender) || isAuthorizedSender(msg.sender, sender);
	}

	function _authorizeSenders(bytes calldata data) internal virtual {
		uint256 length = data.length;
		uint256 offset;

		while (true) {
			_authorizeSender(data[offset:].toAddress());

			unchecked {
				if ((offset += 20) == length) break;
			}
		}
	}

	function _authorizeSender(address sender) internal virtual {
		require(sender != address(0), InvalidSender());
		require(_authorizedSenders.add(msg.sender, sender), AlreadyAuthorized(sender));
		emit Authorized(msg.sender, sender);
	}

	function _setAccountOwner(address newOwner) internal virtual {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))
			mstore(0x20, ACCOUNT_OWNERS_STORAGE_SLOT)
			sstore(keccak256(0x00, 0x40), newOwner)
			log3(0x00, 0x00, ACCOUNT_OWNER_UPDATED_TOPIC, caller(), newOwner)
		}
	}

	function _getAccountOwner(address account) internal view virtual returns (address owner) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, account)))
			mstore(0x20, ACCOUNT_OWNERS_STORAGE_SLOT)
			owner := sload(keccak256(0x00, 0x40))
		}
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

	function _checkDataLength(bytes calldata data) internal pure virtual returns (bool result) {
		assembly ("memory-safe") {
			if iszero(lt(data.length, 0x14)) {
				let quotient := shr(0x40, mul(data.length, 0xCCCCCCCCCCCCD00))
				let remainder := sub(data.length, mul(quotient, 0x14))
				result := iszero(remainder)
			}
		}
	}
}
