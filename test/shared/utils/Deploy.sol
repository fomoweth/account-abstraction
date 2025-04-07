// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {AccountFactory} from "src/factories/AccountFactory.sol";
import {K1ValidatorFactory} from "src/factories/K1ValidatorFactory.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {ModuleFactory} from "src/factories/ModuleFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {Permit2Executor} from "src/modules/executors/Permit2Executor.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";
import {Bootstrap} from "src/Bootstrap.sol";
import {Vortex} from "src/Vortex.sol";

library Deploy {
	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	function vortex(bytes32 salt) internal returns (Vortex instance) {
		bytes memory initCode = type(Vortex).creationCode;

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function bootstrap(bytes32 salt) internal returns (Bootstrap instance) {
		bytes memory initCode = type(Bootstrap).creationCode;

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function metaFactory(bytes32 salt, address initialOwner) internal returns (MetaFactory instance) {
		bytes memory args = abi.encode(initialOwner);
		bytes memory initCode = abi.encodePacked(type(MetaFactory).creationCode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function accountFactory(bytes32 salt, address implementation) internal returns (AccountFactory instance) {
		bytes memory args = abi.encode(implementation);
		bytes memory initCode = abi.encodePacked(type(AccountFactory).creationCode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function k1ValidatorFactory(
		bytes32 salt,
		address implementation,
		address bootstrapper,
		address validator
	) internal returns (K1ValidatorFactory instance) {
		bytes memory args = abi.encode(implementation, bootstrapper, validator);
		bytes memory initCode = abi.encodePacked(type(K1ValidatorFactory).creationCode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function registryFactory(
		bytes32 salt,
		address implementation,
		address bootstrapper,
		address registry,
		address initialOwner
	) internal returns (RegistryFactory instance) {
		bytes memory args = abi.encode(implementation, bootstrapper, registry, initialOwner);
		bytes memory initCode = abi.encodePacked(type(RegistryFactory).creationCode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function moduleFactory(
		bytes32 salt,
		address registry,
		bytes32 resolverUID
	) internal returns (ModuleFactory instance) {
		bytes memory args = abi.encode(registry, resolverUID);
		bytes memory initCode = abi.encodePacked(type(ModuleFactory).creationCode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function k1Validator(ModuleFactory factory, bytes32 salt) internal returns (K1Validator instance) {
		return K1Validator(factory.deployModule(salt, type(K1Validator).creationCode, ""));
	}

	function permit2Executor(ModuleFactory factory, bytes32 salt) internal returns (Permit2Executor instance) {
		return Permit2Executor(factory.deployModule(salt, type(Permit2Executor).creationCode, ""));
	}

	function universalExecutor(
		ModuleFactory factory,
		bytes32 salt,
		address wrappedNative
	) internal returns (UniversalExecutor instance) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = type(UniversalExecutor).creationCode;

		return UniversalExecutor(factory.deployModule(salt, bytecode, args));
	}

	function nativeWrapper(
		ModuleFactory factory,
		bytes32 salt,
		address wrappedNative
	) internal returns (NativeWrapper instance) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = type(NativeWrapper).creationCode;

		return NativeWrapper(factory.deployModule(salt, bytecode, args));
	}

	function stETHWrapper(
		ModuleFactory factory,
		bytes32 salt,
		address stETH,
		address wstETH
	) internal returns (STETHWrapper instance) {
		bytes memory args = abi.encode(stETH, wstETH);
		bytes memory bytecode = type(STETHWrapper).creationCode;

		return STETHWrapper(factory.deployModule(salt, bytecode, args));
	}

	function create2(bytes32 salt, string memory name, bytes memory args) internal returns (address instance) {
		bytes memory bytecode = vm.getCode(string.concat(name, ".sol:", name));
		bytes memory initCode = abi.encodePacked(bytecode, args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}
}
