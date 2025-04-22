// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IModuleFactory} from "src/interfaces/factories/IModuleFactory.sol";
import {IERC7484} from "src/interfaces/registries/IERC7484.sol";

/// @title ModuleFactory
/// @notice Deploys and registers modules compliant with the ERC-7579 standard.
contract ModuleFactory is IModuleFactory {
	/// @dev keccak256("ModuleDeployed(address,bytes32)")
	bytes32 private constant MODULE_DEPLOYED_TOPIC = 0x4f980749b81a25271e0bfdc77dd2910421a2226fe562a239470c55be0903c6cd;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.transient.context")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant CONTEXT_TRANSIENT_SLOT =
		0x840c2bd03063860b15b0896c830a627dd319d8fb64e9b8370fa6cee732293600;

	bytes32 private constant RESOLVER_UID = 0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f;

	/// @notice The ERC-7484 registry contract
	address public immutable REGISTRY;

	constructor(address registry) {
		assembly ("memory-safe") {
			registry := shr(0x60, shl(0x60, registry))
			if iszero(registry) {
				mstore(0x00, 0x81e3306a) // InvalidERC7484Registry()
				revert(0x1c, 0x04)
			}
		}

		REGISTRY = registry;
	}

	/// @inheritdoc IModuleFactory
	function deployModule(
		address registry,
		bytes32 resolverUID,
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) public payable virtual returns (address module) {
		assembly ("memory-safe") {
			function allocate(length) -> ptr {
				ptr := mload(0x40)
				mstore(0x40, add(ptr, length))
			}

			if iszero(bytecode.length) {
				mstore(0x00, 0x21744a59) // EmptyBytecode()
				revert(0x1c, 0x04)
			}

			if gt(params.length, 0xffffffff) {
				mstore(0x00, 0xa2efbdbb) // ExceededMaxParamsLength()
				revert(0x1c, 0x04)
			}

			if iszero(iszero(params.length)) {
				tstore(CONTEXT_TRANSIENT_SLOT, calldataload(sub(params.offset, 0x04)))

				if gt(params.length, sub(0x20, 0x04)) {
					mstore(0x00, CONTEXT_TRANSIENT_SLOT)
					let derivedSlot := keccak256(0x00, 0x20)

					let pos := add(params.offset, sub(0x20, 0x04))
					let guard := sub(add(params.offset, params.length), 0x01)

					// prettier-ignore
					for { } 0x01 { } {
						tstore(derivedSlot, calldataload(pos))
						pos := add(pos, 0x20)
						if gt(pos, guard) { break }
						derivedSlot := add(derivedSlot, 0x01)
					}
				}
			}

			let initCodeSize := add(bytecode.length, params.length)
			let initCode := allocate(initCodeSize)

			calldatacopy(initCode, bytecode.offset, bytecode.length)
			calldatacopy(add(initCode, bytecode.length), params.offset, params.length)

			module := create2(0x00, initCode, initCodeSize, salt)
			if iszero(module) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			log3(codesize(), 0x00, MODULE_DEPLOYED_TOPIC, module, salt)

			tstore(CONTEXT_TRANSIENT_SLOT, 0x00)

			if iszero(iszero(registry)) {
				// prettier-ignore
				if iszero(resolverUID) { resolverUID := RESOLVER_UID }

				let ptr := allocate(0xc4)

				mstore(ptr, 0x88dc678d00000000000000000000000000000000000000000000000000000000) // registerModule(bytes32,address,bytes,bytes)
				mstore(add(ptr, 0x04), resolverUID)
				mstore(add(ptr, 0x24), shr(0x60, shl(0x60, module)))
				mstore(add(ptr, 0x44), 0x80)
				mstore(add(ptr, 0x64), 0xa0)

				if iszero(call(gas(), registry, 0x00, ptr, 0xc4, codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	/// @inheritdoc IModuleFactory
	function deployModule(
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) public payable virtual returns (address module) {
		return deployModule(REGISTRY, RESOLVER_UID, salt, bytecode, params);
	}

	/// @inheritdoc IModuleFactory
	function computeAddress(bytes32 salt, bytes calldata initCode) public view virtual returns (address module) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			calldatacopy(add(ptr, 0x40), initCode.offset, initCode.length)
			mstore(add(ptr, 0x40), keccak256(add(ptr, 0x40), initCode.length))
			mstore(add(ptr, 0x20), salt)
			mstore(ptr, address())
			mstore8(add(ptr, 0x0b), 0xff)

			module := shr(0x60, shl(0x60, keccak256(add(ptr, 0x0b), 0x55)))
		}
	}

	/// @inheritdoc IModuleFactory
	function parameters() external view returns (bytes memory context) {
		assembly ("memory-safe") {
			context := mload(0x40)

			mstore(context, 0x00)
			mstore(add(context, sub(0x20, 0x04)), tload(CONTEXT_TRANSIENT_SLOT))

			let length := mload(context)
			let offset := add(context, 0x20)
			mstore(0x40, add(offset, length))

			if gt(length, sub(0x20, 0x04)) {
				mstore(0x00, CONTEXT_TRANSIENT_SLOT)
				let slot := keccak256(0x00, 0x20)

				let pos := add(offset, sub(0x20, 0x04))
				let guard := add(offset, length)

				// prettier-ignore
				for { } 0x01 { } {
					mstore(pos, tload(slot))
					pos := add(pos, 0x20)
					if gt(pos, guard) { break }
					slot := add(slot, 0x01)
				}

				mstore(guard, 0x00)
			}
		}
	}

	/// @inheritdoc IModuleFactory
	function name() external pure returns (string memory) {
		return "ModuleFactory";
	}

	/// @inheritdoc IModuleFactory
	function version() external pure returns (string memory) {
		return "1.0.0";
	}
}
