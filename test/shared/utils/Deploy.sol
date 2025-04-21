// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {TransparentUpgradeableProxy, ProxyAdmin} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IERC7484} from "src/interfaces/registries/IERC7484.sol";
import {IRegistry} from "src/interfaces/registries/IRegistry.sol";
import {Currency} from "src/types/Currency.sol";
import {AccountFactory} from "src/factories/AccountFactory.sol";
import {K1ValidatorFactory} from "src/factories/K1ValidatorFactory.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {ModuleFactory} from "src/factories/ModuleFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {Permit2Executor} from "src/modules/executors/Permit2Executor.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";
import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {STETHWrapperFallback} from "src/modules/fallbacks/STETHWrapperFallback.sol";
import {ECDSAValidator} from "src/modules/validators/ECDSAValidator.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";
import {Bootstrap} from "src/Bootstrap.sol";
import {Vortex} from "src/Vortex.sol";

library Deploy {
	Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	bytes32 private constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

	bytes32 private constant ERC1967_IMPLEMENTATION_SLOT =
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

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
		bytes memory initCode = abi.encodePacked(type(MetaFactory).creationCode, abi.encode(initialOwner));

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function accountFactory(
		bytes32 salt,
		Vortex implementation,
		address initialOwner
	) internal returns (AccountFactory instance) {
		bytes memory args = abi.encode(implementation, initialOwner);
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
		Vortex implementation,
		K1Validator validator,
		Bootstrap bootstrapper,
		IRegistry registry,
		address initialOwner
	) internal returns (K1ValidatorFactory instance) {
		bytes memory args = abi.encode(implementation, validator, bootstrapper, registry, initialOwner);
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
		Vortex implementation,
		Bootstrap bootstrapper,
		IRegistry registry,
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

	function moduleFactory(bytes32 salt, IRegistry registry) internal returns (ModuleFactory instance) {
		bytes memory args = abi.encode(registry);
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

	function k1Validator(ModuleFactory factory, bytes32 salt) internal returns (K1Validator) {
		return K1Validator(factory.deployModule(salt, type(K1Validator).creationCode, ""));
	}

	function ecdsaValidator(ModuleFactory factory, bytes32 salt) internal returns (ECDSAValidator) {
		return ECDSAValidator(factory.deployModule(salt, type(ECDSAValidator).creationCode, ""));
	}

	function permit2Executor(ModuleFactory factory, bytes32 salt) internal returns (Permit2Executor) {
		return Permit2Executor(factory.deployModule(salt, type(Permit2Executor).creationCode, ""));
	}

	function universalExecutor(
		ModuleFactory factory,
		bytes32 salt,
		Currency wrappedNative
	) internal returns (UniversalExecutor) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = type(UniversalExecutor).creationCode;

		return UniversalExecutor(factory.deployModule(salt, bytecode, args));
	}

	function nativeWrapper(
		ModuleFactory factory,
		bytes32 salt,
		Currency wrappedNative
	) internal returns (NativeWrapperFallback) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = type(NativeWrapperFallback).creationCode;

		return NativeWrapperFallback(factory.deployModule(salt, bytecode, args));
	}

	function stETHWrapper(
		ModuleFactory factory,
		bytes32 salt,
		Currency stETH,
		Currency wstETH
	) internal returns (STETHWrapperFallback) {
		bytes memory args = abi.encode(stETH, wstETH);
		bytes memory bytecode = type(STETHWrapperFallback).creationCode;

		return STETHWrapperFallback(factory.deployModule(salt, bytecode, args));
	}

	function transparentUpgradeableProxy(
		bytes32 salt,
		address implementation,
		address admin,
		bytes memory data
	) internal returns (TransparentUpgradeableProxy proxy, ProxyAdmin proxyAdmin) {
		bytes memory args = abi.encode(implementation, admin, data);
		bytes memory initCode = abi.encodePacked(type(TransparentUpgradeableProxy).creationCode, args);

		assembly ("memory-safe") {
			proxy := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(proxy) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT)))));
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
