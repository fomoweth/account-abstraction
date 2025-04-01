// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVortexFactory} from "src/interfaces/factories/IVortexFactory.sol";
import {IVortex} from "src/interfaces/IVortex.sol";
import {IBootstrap} from "src/interfaces/IBootstrap.sol";
import {BootstrapLib, BootstrapConfig} from "src/libraries/BootstrapLib.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_STATELESS_VALIDATOR} from "src/types/ModuleType.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title VortexFactory
/// @notice Manages the creation of Modular Smart Accounts compliant with ERC-7579 and ERC-4337 using K1 validator and ERC-7484 registry

contract VortexFactory is IVortexFactory, AccountFactory {
	using BootstrapLib for address;

	address public immutable BOOTSTRAP;

	address public immutable K1_VALIDATOR;

	constructor(address implementation, address bootstrap, address k1Validator) AccountFactory(implementation) {
		assembly ("memory-safe") {
			bootstrap := shr(0x60, shl(0x60, bootstrap))
			if iszero(bootstrap) {
				mstore(0x00, 0x5368eac9) // InvalidBootstrap()
				revert(0x1c, 0x04)
			}

			k1Validator := shr(0x60, shl(0x60, k1Validator))
			if iszero(k1Validator) {
				mstore(0x00, 0x93464e8d) // InvalidK1Validator()
				revert(0x1c, 0x04)
			}
		}

		BOOTSTRAP = bootstrap;
		K1_VALIDATOR = k1Validator;
	}

	function createAccount(
		bytes32 salt,
		bytes calldata data
	) public payable virtual override(IAccountFactory, AccountFactory) returns (address payable account) {
		address eoaOwner;
		address[] calldata senders;
		address registry;
		address[] calldata attesters;
		uint8 threshold;

		assembly ("memory-safe") {
			eoaOwner := calldataload(data.offset)

			let ptr := add(data.offset, calldataload(add(data.offset, 0x20)))
			senders.length := calldataload(ptr)
			senders.offset := add(ptr, 0x20)

			registry := shr(0x60, shl(0x60, calldataload(add(data.offset, 0x40))))

			ptr := add(data.offset, calldataload(add(data.offset, 0x60)))
			attesters.length := calldataload(ptr)
			attesters.offset := add(ptr, 0x20)

			threshold := and(calldataload(add(data.offset, 0x80)), 0xff)
		}

		return createAccount(salt, eoaOwner, senders, registry, attesters, threshold);
	}

	function createAccount(
		bytes32 salt,
		address eoaOwner,
		address[] calldata senders,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) public payable virtual returns (address payable account) {
		assembly ("memory-safe") {
			eoaOwner := shr(0x60, shl(0x60, eoaOwner))
			if or(iszero(eoaOwner), iszero(iszero(extcodesize(eoaOwner)))) {
				mstore(0x00, 0x5c6a4407) // InvalidEOAOwner()
				revert(0x1c, 0x04)
			}

			registry := shr(0x60, shl(0x60, registry))
			if and(iszero(extcodesize(registry)), iszero(iszero(threshold))) {
				mstore(0x00, 0x81e3306a) // InvalidERC7484Registry()
				revert(0x1c, 0x04)
			}

			if gt(threshold, attesters.length) {
				mstore(0x00, 0xaabd5a09) // InvalidThreshold()
				revert(0x1c, 0x04)
			}
		}

		ModuleType[] memory moduleTypeIds = new ModuleType[](2);
		moduleTypeIds[0] = MODULE_TYPE_VALIDATOR;
		moduleTypeIds[1] = MODULE_TYPE_STATELESS_VALIDATOR;

		bytes memory data = abi.encodePacked(eoaOwner);
		uint256 length = senders.length;

		for (uint256 i; i < length; ) {
			data = abi.encodePacked(data, senders[i]);

			unchecked {
				i = i + 1;
			}
		}

		bytes memory initializer = IBootstrap(BOOTSTRAP).getInitializeScopedCalldata(
			K1_VALIDATOR.build(moduleTypeIds, data, ""),
			registry,
			attesters,
			threshold
		);

		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, abi.encodeCall(IVortex.initializeAccount, (initializer)));
	}
}
