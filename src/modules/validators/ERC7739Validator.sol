// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {CustomRevert} from "src/libraries/CustomRevert.sol";
import {ValidatorBase} from "./ValidatorBase.sol";

/// @title ERC7739Validator
/// @notice Verifies user operation signatures for smart accounts

contract ERC7739Validator is ValidatorBase {
	using CalldataDecoder for bytes;
	using CustomRevert for bytes4;

	mapping(address account => address owner) internal _accountOwners;

	function onInstall(bytes calldata data) external payable {
		if (_isInitialized(msg.sender)) AlreadyInitialized.selector.revertWith(msg.sender);
		if (data.length < 20) InvalidDataLength.selector.revertWith();

		_setOwner(msg.sender, data.decodeAddress(0));
	}

	function onUninstall(bytes calldata) external payable {
		if (!_isInitialized(msg.sender)) NotInitialized.selector.revertWith();
		delete _accountOwners[msg.sender];
	}

	function transferOwnership(address newOwner) external {
		_setOwner(msg.sender, newOwner);
	}

	function _setOwner(address account, address newOwner) internal virtual {
		_checkNewOwner(newOwner);
		_accountOwners[account] = newOwner;
	}

	function getOwner(address account) external view returns (address) {
		return _getOwner(account);
	}

	function _getOwner(address account) internal view virtual returns (address owner) {
		return _accountOwners[account];
	}

	function _erc1271Signer() internal view virtual override returns (address) {
		return _getOwner(msg.sender);
	}

	function name() public pure returns (string memory) {
		return "ERC7739Validator";
	}

	function version() public pure returns (string memory) {
		return "1.0.0";
	}

	function _domainNameAndVersion() internal pure virtual override returns (string memory, string memory) {
		return (name(), version());
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function _isInitialized(address account) internal view virtual returns (bool) {
		return _getOwner(account) != address(0);
	}

	function _checkNewOwner(address newOwner) private view {
		assembly ("memory-safe") {
			if or(iszero(newOwner), iszero(iszero(extcodesize(newOwner)))) {
				mstore(0x00, 0x54a56786) // InvalidNewOwner()
				revert(0x1c, 0x04)
			}
		}
	}
}
