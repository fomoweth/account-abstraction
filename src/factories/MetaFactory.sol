// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";

/// @title MetaFactory
/// @notice Coordinates the creation of ERC-4337 and ERC-7579-compliant smart accounts
/// through authorized factories and handles the permission management of those factories.
contract MetaFactory is IMetaFactory, StakingAdapter {
	mapping(address factory => bool) internal _isAuthorized;

	constructor(address initialOwner) StakingAdapter(initialOwner) {}

	/// @inheritdoc IMetaFactory
	function createAccount(bytes calldata params) external payable returns (address payable account) {
		assembly ("memory-safe") {
			if lt(params.length, 0x58) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}

			let factory := shr(0x60, calldataload(params.offset))
			params.offset := add(params.offset, 0x14)
			params.length := sub(params.length, 0x14)

			if iszero(shl(0x60, factory)) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			mstore(0x00, factory)
			mstore(0x20, _isAuthorized.slot)

			if iszero(sload(keccak256(0x00, 0x40))) {
				mstore(0x00, 0x644c0c49) // FactoryNotAuthorized(address)
				mstore(0x20, factory)
				revert(0x1c, 0x24)
			}

			let ptr := mload(0x40)

			calldatacopy(ptr, params.offset, params.length)

			if iszero(call(gas(), factory, callvalue(), ptr, params.length, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			account := mload(0x00)
		}
	}

	/// @inheritdoc IMetaFactory
	function computeAddress(address factory, bytes32 salt) external view returns (address payable account) {
		assembly ("memory-safe") {
			if iszero(shl(0x60, factory)) {
				mstore(0x00, 0x7a44db95) // InvalidFactory()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x7fde56da00000000000000000000000000000000000000000000000000000000) // computeAddress(bytes32)
			mstore(add(ptr, 0x04), salt)

			if iszero(staticcall(gas(), factory, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			account := mload(0x00)
		}
	}

	/// @inheritdoc IMetaFactory
	function authorize(address factory) external payable onlyOwner {
		_checkAuthority(factory, true);
		_isAuthorized[factory] = true;
		emit FactoryAuthorized(factory);
	}

	/// @inheritdoc IMetaFactory
	function revoke(address factory) external payable onlyOwner {
		_checkAuthority(factory, false);
		_isAuthorized[factory] = false;
		emit FactoryRevoked(factory);
	}

	/// @inheritdoc IMetaFactory
	function isAuthorized(address factory) public view virtual returns (bool) {
		return _isAuthorized[factory];
	}

	/// @inheritdoc IMetaFactory
	function checkAuthority(address factory) external view {
		_checkAuthority(factory, false);
	}

	/// @inheritdoc IMetaFactory
	function name() external pure returns (string memory) {
		return "MetaFactory";
	}

	/// @inheritdoc IMetaFactory
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function _checkAuthority(address factory, bool flag) internal view virtual {
		require(factory != address(0), InvalidFactory());
		if (!flag) require(isAuthorized(factory), FactoryNotAuthorized(factory));
		else require(!isAuthorized(factory), FactoryAlreadyAuthorized(factory));
	}
}
