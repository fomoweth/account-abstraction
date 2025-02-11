// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistryFactory} from "src/interfaces/factories/IRegistryFactory.sol";
import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {Ownable} from "src/utils/Ownable.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title RegistryFactory

contract RegistryFactory is IRegistryFactory, AccountFactory, Ownable {
	/// @dev keccak256("AttestersConfigured(uint256,uint8)")
	bytes32 private constant ATTESTERS_CONFIGURED_TOPIC =
		0xc14f893b670961f12951ae84c405bc2e99f77d9000a2ae42a34adfa0dbd429b5;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.attesters")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant ATTESTERS_SLOT = 0x591d670101e679b166bb53529c21081533156f5a77b025e5e95f23dd51cbd500;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.threshold")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant THRESHOLD_SLOT = 0xbd0973d179e1f52a52f8122a9dbb94f0219248b29ce16d6f17a987d4a467a200;

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	address public immutable REGISTRY;

	constructor(
		address implementation,
		address registry,
		address[] memory attesters,
		uint8 threshold,
		address initialOwner
	) AccountFactory(implementation) {
		assembly ("memory-safe") {
			registry := shr(0x60, shl(0x60, registry))
			if iszero(extcodesize(registry)) {
				mstore(0x00, 0x81e3306a) // InvalidERC7484Registry()
				revert(0x1c, 0x04)
			}
		}

		REGISTRY = registry;
		_initializeAttesters(registry, attesters, threshold);
		_initializeOwner(initialOwner);
	}

	function createAccount(
		bytes32 salt,
		bytes calldata data
	) public payable virtual override(IAccountFactory, AccountFactory) returns (address payable account) {
		bytes calldata initializer;
		assembly ("memory-safe") {
			initializer.offset := add(data.offset, 0x5c)
			initializer.length := sub(data.length, 0x5c)
		}

		(
			BootstrapConfig memory rootValidator,
			BootstrapConfig memory hook,
			BootstrapConfig[] memory validators,
			BootstrapConfig[] memory executors,
			BootstrapConfig[] memory fallbacks,
			,
			,

		) = abi.decode(
				initializer,
				(
					BootstrapConfig,
					BootstrapConfig,
					BootstrapConfig[],
					BootstrapConfig[],
					BootstrapConfig[],
					address,
					address[],
					uint8
				)
			);

		_checkRegistry(REGISTRY, rootValidator.module, MODULE_TYPE_VALIDATOR, getAttesters());

		if (hook.module != SENTINEL) {
			_checkRegistry(REGISTRY, hook.module, MODULE_TYPE_HOOK, getAttesters());
		}

		address module;
		uint256 length = validators.length;
		for (uint256 i; i < length; ) {
			if ((module = validators[i].module) == ZERO) break;
			_checkRegistry(REGISTRY, module, MODULE_TYPE_VALIDATOR, getAttesters());

			unchecked {
				i = i + 1;
			}
		}

		length = executors.length;
		for (uint256 i; i < length; ) {
			if ((module = executors[i].module) == ZERO) break;
			_checkRegistry(REGISTRY, module, MODULE_TYPE_EXECUTOR, getAttesters());

			unchecked {
				i = i + 1;
			}
		}

		length = fallbacks.length;
		for (uint256 i; i < length; ) {
			if ((module = fallbacks[i].module) == ZERO) break;
			_checkRegistry(REGISTRY, module, MODULE_TYPE_FALLBACK, getAttesters());

			unchecked {
				i = i + 1;
			}
		}

		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, data);
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
			sstore(THRESHOLD_SLOT, and(threshold, 0xff))

			// store the length of attesters array
			sstore(ATTESTERS_SLOT, attesters.length)

			// compute the location of attesters array storage slot
			mstore(0x00, ATTESTERS_SLOT)
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
			sstore(THRESHOLD_SLOT, and(threshold, 0xff))

			// store the length of attesters array
			sstore(ATTESTERS_SLOT, length)

			// compute the location of attesters array storage slot
			mstore(0x00, ATTESTERS_SLOT)
			let slot := keccak256(0x00, 0x20)

			// construct the call data
			let ptr := mload(0x40)

			mstore(ptr, 0xf05c04e100000000000000000000000000000000000000000000000000000000) // trustAttesters(uint8,address[])
			mstore(add(ptr, 0x04), and(threshold, 0xff))
			mstore(add(ptr, 0x24), 0x40)
			mstore(add(ptr, 0x44), length)

			// prettier-ignore
			for { let i } 0x01 { } {
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

				i := add(i, 0x01)
				if eq(i, length) { break }
			}

			if iszero(call(gas(), registry, 0x00, ptr, add(shl(0x05, length), 0x64), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			log3(0x00, 0x00, ATTESTERS_CONFIGURED_TOPIC, length, threshold)
		}
	}

	function _checkRegistry(
		address registry,
		address module,
		ModuleType moduleTypeId,
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
			mstore(add(ptr, 0x64), and(sload(THRESHOLD_SLOT), 0xff))
			mstore(add(ptr, 0x84), length)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(add(ptr, 0xa4), shl(0x05, i)), mload(add(offset, shl(0x05, i))))
			}

			mstore(0x40, and(add(add(add(ptr, 0xa4), shl(0x05, length)), 0x1f), not(0x1f)))

			if iszero(staticcall(gas(), registry, ptr, add(shl(0x05, length), 0xa4), 0x00, 0x00)) {
				mstore(0x00, 0xa21f4c05) // ModuleNotWhitelisted(address,uint256)
				mstore(0x20, shr(0x60, shl(0x60, module)))
				mstore(0x40, moduleTypeId)
				revert(0x1c, 0x44)
			}
		}
	}

	function getThreshold() public view virtual returns (uint8 threshold) {
		assembly ("memory-safe") {
			threshold := sload(THRESHOLD_SLOT)
		}
	}

	function getAttestersLength() public view virtual returns (uint256 length) {
		assembly ("memory-safe") {
			length := sload(ATTESTERS_SLOT)
		}
	}

	function getAttesters() public view virtual returns (address[] memory attesters) {
		assembly ("memory-safe") {
			mstore(0x00, ATTESTERS_SLOT)
			let slot := keccak256(0x00, 0x20)

			attesters := mload(0x40)

			let length := sload(ATTESTERS_SLOT)
			let offset := add(attesters, 0x20)

			mstore(attesters, length)
			mstore(0x40, add(offset, shl(0x05, length)))

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(offset, shl(0x05, i)), sload(add(slot, i)))
			}
		}
	}

	function isAuthorized(address attester) public view virtual returns (bool result) {
		(result, ) = _findAttester(getAttesters(), attester);
	}

	function _findAttester(
		address[] memory attesters,
		address target
	) private pure returns (bool found, uint256 index) {
		assembly ("memory-safe") {
			let w := not(0x00)
			let l := 0x01
			let h := mload(attesters)
			let t

			// prettier-ignore
			for { } 0x01 { } {
                index := shr(0x01, add(l, h))
                t := mload(add(attesters, shl(0x05, index)))
                if or(gt(l, h), eq(t, target)) { break }
                if iszero(gt(target, t)) {
                    h := add(index, w)
                    continue
                }
                l := add(index, 0x01)
            }
			found := eq(t, target)
			t := iszero(iszero(index))
			index := mul(add(index, w), t)
			found := and(found, t)
		}
	}
}
