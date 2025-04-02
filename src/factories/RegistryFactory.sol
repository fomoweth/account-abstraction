// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistryFactory} from "src/interfaces/factories/IRegistryFactory.sol";
import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {IVortex} from "src/interfaces/IVortex.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/ModuleType.sol";
import {Ownable} from "src/utils/Ownable.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title RegistryFactory

contract RegistryFactory is IRegistryFactory, AccountFactory, Ownable {
	using Arrays for address[];

	/// @dev keccak256("AttestersConfigured(uint256,uint8)")
	bytes32 private constant ATTESTERS_CONFIGURED_TOPIC =
		0xc14f893b670961f12951ae84c405bc2e99f77d9000a2ae42a34adfa0dbd429b5;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.attesters")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant ATTESTERS_STORAGE_SLOT =
		0x591d670101e679b166bb53529c21081533156f5a77b025e5e95f23dd51cbd500;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.threshold")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant THRESHOLD_STORAGE_SLOT =
		0xbd0973d179e1f52a52f8122a9dbb94f0219248b29ce16d6f17a987d4a467a200;

	address public immutable BOOTSTRAP;

	address public immutable REGISTRY;

	constructor(
		address implementation,
		address bootstrap,
		address registry,
		address initialOwner
	) AccountFactory(implementation) {
		assembly ("memory-safe") {
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

		BOOTSTRAP = bootstrap;
		REGISTRY = registry;
		_initializeOwner(initialOwner);
	}

	function createAccount(
		bytes32 salt,
		bytes calldata params
	) public payable virtual override(IAccountFactory, AccountFactory) returns (address payable account) {
		BootstrapConfig calldata rootValidator;
		BootstrapConfig[] calldata validators;
		BootstrapConfig[] calldata executors;
		BootstrapConfig[] calldata fallbacks;
		BootstrapConfig[] calldata hooks;

		assembly ("memory-safe") {
			let ptr := add(params.offset, calldataload(params.offset))
			rootValidator := ptr

			ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			validators.offset := add(ptr, 0x20)
			validators.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x40)))
			executors.offset := add(ptr, 0x20)
			executors.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x60)))
			fallbacks.offset := add(ptr, 0x20)
			fallbacks.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x80)))
			hooks.offset := add(ptr, 0x20)
			hooks.length := calldataload(ptr)
		}

		return createAccount(salt, rootValidator, validators, executors, fallbacks, hooks);
	}

	function createAccount(
		bytes32 salt,
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks
	) public payable virtual returns (address payable account) {
		address[] memory attesters = getAttesters();
		uint8 threshold = getThreshold();

		_checkRegistry(REGISTRY, MODULE_TYPE_VALIDATOR, rootValidator.module, threshold, attesters);

		uint256 length = validators.length;
		for (uint256 i; i < length; ) {
			_checkRegistry(REGISTRY, MODULE_TYPE_VALIDATOR, validators[i].module, threshold, attesters);

			unchecked {
				i = i + 1;
			}
		}

		length = executors.length;
		for (uint256 i; i < length; ) {
			_checkRegistry(REGISTRY, MODULE_TYPE_EXECUTOR, executors[i].module, threshold, attesters);

			unchecked {
				i = i + 1;
			}
		}

		length = fallbacks.length;
		for (uint256 i; i < length; ) {
			_checkRegistry(REGISTRY, MODULE_TYPE_FALLBACK, fallbacks[i].module, threshold, attesters);

			unchecked {
				i = i + 1;
			}
		}

		length = hooks.length;
		for (uint256 i; i < length; ) {
			_checkRegistry(REGISTRY, MODULE_TYPE_HOOK, hooks[i].module, threshold, attesters);

			unchecked {
				i = i + 1;
			}
		}

		bytes memory initializer = IBootstrap(BOOTSTRAP).getInitializeCalldata(
			rootValidator,
			validators,
			executors,
			fallbacks,
			hooks,
			REGISTRY,
			attesters,
			threshold
		);

		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, abi.encodeCall(IVortex.initializeAccount, (initializer)));
	}

	function configureAttesters(address[] calldata attesters, uint8 threshold) external payable onlyOwner {
		_configureAttesters(REGISTRY, attesters, threshold);
	}

	function _configureAttesters(address registry, address[] calldata attesters, uint8 threshold) internal virtual {
		assembly ("memory-safe") {
			if or(iszero(threshold), gt(threshold, attesters.length)) {
				mstore(0x00, 0xaabd5a09) // InvalidThreshold()
				revert(0x1c, 0x04)
			}

			// construct the call data
			let ptr := mload(0x40)

			mstore(ptr, 0xf05c04e100000000000000000000000000000000000000000000000000000000) // trustAttesters(uint8,address[])
			mstore(add(ptr, 0x04), and(threshold, 0xff))
			mstore(add(ptr, 0x24), 0x40)
			mstore(add(ptr, 0x44), attesters.length)
			calldatacopy(add(ptr, 0x64), attesters.offset, shl(0x05, attesters.length))

			if iszero(call(gas(), registry, 0x00, ptr, add(shl(0x05, attesters.length), 0x64), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			// store the threshold
			sstore(THRESHOLD_STORAGE_SLOT, and(threshold, 0xff))

			// store the length of attesters array
			sstore(ATTESTERS_STORAGE_SLOT, attesters.length)

			// compute the location of attesters array storage slot
			mstore(0x00, ATTESTERS_STORAGE_SLOT)
			let slot := keccak256(0x00, 0x20)

			// attesters and threshold are validated by the registry at this point; therefore, we could skip the validation
			// prettier-ignore
			for { let i } lt(i, attesters.length) { i := add(i, 0x01) } {
				// store the attester at current index
				sstore(add(slot, i), calldataload(add(attesters.offset, shl(0x05, i))))
			}

			log3(0x00, 0x00, ATTESTERS_CONFIGURED_TOPIC, attesters.length, threshold)
		}
	}

	function _initializeAttesters(address registry, address[] memory attesters, uint8 threshold) internal virtual {
		assembly ("memory-safe") {
			let length := mload(attesters)
			let offset := add(attesters, 0x20)

			if or(iszero(threshold), gt(threshold, length)) {
				mstore(0x00, 0xaabd5a09) // InvalidThreshold()
				revert(0x1c, 0x04)
			}

			if iszero(mload(offset)) {
				mstore(0x00, 0xb8daf542) // InvalidAttester()
				revert(0x1c, 0x04)
			}

			// store the threshold
			sstore(THRESHOLD_STORAGE_SLOT, and(threshold, 0xff))

			// store the length of attesters array
			sstore(ATTESTERS_STORAGE_SLOT, length)

			// compute the location of attesters array storage slot
			mstore(0x00, ATTESTERS_STORAGE_SLOT)
			let slot := keccak256(0x00, 0x20)

			// construct the call data
			let ptr := mload(0x40)

			mstore(ptr, 0xf05c04e100000000000000000000000000000000000000000000000000000000) // trustAttesters(uint8,address[])
			mstore(add(ptr, 0x04), and(threshold, 0xff))
			mstore(add(ptr, 0x24), 0x40)
			mstore(add(ptr, 0x44), length)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				let attester := mload(offset)
				offset := add(offset, 0x20)
				let attesterNext := mload(offset)

				// validate that the attesters are sorted
				if iszero(lt(attester, attesterNext)) {
					mstore(0x00, 0x8e378be0) // AttestersNotSorted()
					revert(0x1c, 0x04)
				}

				// store the attester at current index
				sstore(add(slot, i), attester)
				mstore(add(add(ptr, 0x64), shl(0x05, i)), attester)
			}

			if iszero(call(gas(), registry, 0x00, ptr, add(shl(0x05, length), 0x64), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			log3(0x00, 0x00, ATTESTERS_CONFIGURED_TOPIC, length, threshold)
		}
	}

	function getThreshold() public view virtual returns (uint8 threshold) {
		assembly ("memory-safe") {
			threshold := sload(THRESHOLD_STORAGE_SLOT)
		}
	}

	function getAttesters() public view virtual returns (address[] memory attesters) {
		assembly ("memory-safe") {
			attesters := mload(0x40)

			let length := sload(ATTESTERS_STORAGE_SLOT)
			let offset := add(attesters, 0x20)

			mstore(attesters, length)
			mstore(0x40, add(offset, shl(0x05, length)))

			mstore(0x00, ATTESTERS_STORAGE_SLOT)
			let slot := keccak256(0x00, 0x20)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(offset, shl(0x05, i)), sload(add(slot, i)))
			}
		}
	}

	function isAuthorized(address attester) public view virtual returns (bool result) {
		return getAttesters().inSorted(attester);
	}

	function _checkRegistry(
		address registry,
		ModuleType moduleTypeId,
		address module,
		uint8 threshold,
		address[] memory attesters
	) internal view virtual {
		assembly ("memory-safe") {
			let length := mload(attesters)
			let offset := add(attesters, 0x20)
			let ptr := mload(0x40)

			mstore(ptr, 0x2ed9446700000000000000000000000000000000000000000000000000000000) // check(address,uint256,address[],uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, module)))
			mstore(add(ptr, 0x24), moduleTypeId)
			mstore(add(ptr, 0x44), 0x80)
			mstore(add(ptr, 0x64), and(threshold, 0xff))
			mstore(add(ptr, 0x84), length)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(add(ptr, 0xa4), shl(0x05, i)), mload(add(offset, shl(0x05, i))))
			}

			mstore(0x40, and(add(add(add(ptr, 0xa4), shl(0x05, length)), 0x1f), not(0x1f)))

			if iszero(staticcall(gas(), registry, ptr, add(shl(0x05, length), 0xa4), 0x00, 0x00)) {
				mstore(0x00, 0xdcd833b4) // ModuleNotAuthorized(address,uint256)
				mstore(0x20, shr(0x60, shl(0x60, module)))
				mstore(0x40, moduleTypeId)
				revert(0x1c, 0x44)
			}
		}
	}
}
