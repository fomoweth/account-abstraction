// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IK1ValidatorFactory} from "src/interfaces/factories/IK1ValidatorFactory.sol";
import {IERC7484} from "src/interfaces/registries/IERC7484.sol";
import {IBootstrap} from "src/interfaces/IBootstrap.sol";
import {IVortex} from "src/interfaces/IVortex.sol";
import {BootstrapLib, BootstrapConfig} from "src/libraries/BootstrapLib.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_STATELESS_VALIDATOR} from "src/types/ModuleType.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title K1ValidatorFactory
/// @notice Manages smart account creation compliant with ERC-4337 and ERC-7579 with K1Validator
contract K1ValidatorFactory is IK1ValidatorFactory, AccountFactory {
	using BootstrapLib for address;

	/// @notice The K1Validator module contract
	address public immutable K1_VALIDATOR;

	/// @notice The Vortex Bootstrap contract
	IBootstrap public immutable BOOTSTRAP;

	/// @notice The ERC-7484 registry contract
	IERC7484 public immutable REGISTRY;

	constructor(
		address implementation,
		address k1Validator,
		address bootstrap,
		address registry,
		address initialOwner
	) AccountFactory(implementation, initialOwner) {
		assembly ("memory-safe") {
			k1Validator := shr(0x60, shl(0x60, k1Validator))
			if iszero(k1Validator) {
				mstore(0x00, 0x93464e8d) // InvalidK1Validator()
				revert(0x1c, 0x04)
			}

			bootstrap := shr(0x60, shl(0x60, bootstrap))
			if iszero(bootstrap) {
				mstore(0x00, 0x5368eac9) // InvalidBootstrap()
				revert(0x1c, 0x04)
			}

			registry := shr(0x60, shl(0x60, registry))
			if iszero(registry) {
				mstore(0x00, 0x81e3306a) // InvalidERC7484Registry()
				revert(0x1c, 0x04)
			}
		}

		K1_VALIDATOR = k1Validator;
		BOOTSTRAP = IBootstrap(bootstrap);
		REGISTRY = IERC7484(registry);
	}

	/// @inheritdoc IAccountFactory
	function createAccount(
		bytes32 salt,
		bytes calldata params
	) public payable virtual override(IAccountFactory, AccountFactory) returns (address payable account) {
		address eoaOwner;
		address[] calldata senders;
		address registry;
		address[] calldata attesters;
		uint8 threshold;

		assembly ("memory-safe") {
			eoaOwner := calldataload(params.offset)

			let ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			senders.offset := add(ptr, 0x20)
			senders.length := calldataload(ptr)

			registry := shr(0x60, shl(0x60, calldataload(add(params.offset, 0x40))))

			ptr := add(params.offset, calldataload(add(params.offset, 0x60)))
			attesters.offset := add(ptr, 0x20)
			attesters.length := calldataload(ptr)

			threshold := and(calldataload(add(params.offset, 0x80)), 0xff)
		}

		return createAccount(salt, eoaOwner, senders, registry, attesters, threshold);
	}

	/// @inheritdoc IK1ValidatorFactory
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
			if and(iszero(registry), iszero(iszero(threshold))) {
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

		bytes memory params = abi.encodeCall(
			IVortex.initializeAccount,
			(
				BOOTSTRAP.getInitializeScopedCalldata(
					K1_VALIDATOR.build(moduleTypeIds, data, ""),
					registry,
					attesters,
					threshold
				)
			)
		);

		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, params);
	}

	/// @inheritdoc IAccountFactory
	function name() public pure virtual override(IAccountFactory, AccountFactory) returns (string memory) {
		return "K1ValidatorFactory";
	}

	/// @inheritdoc IAccountFactory
	function version() public pure virtual override(IAccountFactory, AccountFactory) returns (string memory) {
		return "1.0.0";
	}
}
