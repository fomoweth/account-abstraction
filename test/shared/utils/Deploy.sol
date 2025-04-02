// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {AccountFactory} from "src/factories/AccountFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {K1ValidatorFactory} from "src/factories/K1ValidatorFactory.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";
import {Permit2Executor} from "src/modules/executors/Permit2Executor.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {Bootstrap} from "src/Bootstrap.sol";
import {Vortex} from "src/Vortex.sol";

library Deploy {
	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	bytes32 internal constant VALIDATOR_SALT = 0x000000000000000000000000000000000000000076616c696461746f72000000;

	bytes32 internal constant EXECUTOR_SALT = 0x00000000000000000000000000000000000000006578656375746f7200000000;

	bytes32 internal constant FALLBACK_SALT = 0x000000000000000000000000000000000000000066616c6c6261636b00000000;

	bytes32 internal constant HOOK_SALT = 0x0000000000000000000000000000000000000000686f6f6b0000000000000000;

	bytes32 internal constant SIGNER_SALT = 0x00000000000000000000000000000000000000007369676e6572000000000000;

	bytes32 internal constant POLICY_SALT = 0x0000000000000000000000000000000000000000706f6c696379000000000000;

	function vortex(bytes32 salt) internal returns (Vortex instance) {
		bytes memory initCode = abi.encodePacked(type(Vortex).creationCode);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(address(instance), "VortexImplementation");
	}

	function bootstrap(bytes32 salt) internal returns (Bootstrap instance) {
		bytes memory initCode = abi.encodePacked(type(Bootstrap).creationCode);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(address(instance), "Bootstrap");
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

		label(address(instance), "MetaFactory");
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

		label(address(instance), "AccountFactory");
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

		label(address(instance), "RegistryFactory");
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

		label(address(instance), "K1ValidatorFactory");
	}

	function k1Validator(bytes32 salt) internal returns (K1Validator instance) {
		bytes memory initCode = abi.encodePacked(type(K1Validator).creationCode);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(address(instance), "K1Validator");
	}

	function permit2Executor(bytes32 salt) internal returns (Permit2Executor instance) {
		bytes memory initCode = abi.encodePacked(type(Permit2Executor).creationCode);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(address(instance), "Permit2Executor");
	}

	function universalExecutor(
		MetaFactory factory,
		bytes32 salt,
		address wrappedNative
	) internal returns (UniversalExecutor instance) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = abi.encodePacked(type(UniversalExecutor).creationCode);

		label(address(instance = UniversalExecutor(factory.deployModule(salt, bytecode, args))), "UniversalExecutor");
	}

	function nativeWrapper(
		MetaFactory factory,
		bytes32 salt,
		address wrappedNative
	) internal returns (NativeWrapper instance) {
		bytes memory args = abi.encode(wrappedNative);
		bytes memory bytecode = abi.encodePacked(type(NativeWrapper).creationCode);

		label(address(instance = NativeWrapper(factory.deployModule(salt, bytecode, args))), "NativeWrapper");
	}

	function stETHWrapper(
		MetaFactory factory,
		bytes32 salt,
		address stETH,
		address wstETH
	) internal returns (STETHWrapper instance) {
		bytes memory args = abi.encode(stETH, wstETH);
		bytes memory bytecode = abi.encodePacked(Deploy.getCode("STETHWrapper"));

		label(address(instance = STETHWrapper(factory.deployModule(salt, bytecode, args))), "STETHWrapper");
	}

	function transparentUpgradeableProxy(
		bytes32 salt,
		string memory name,
		address implementation,
		address admin,
		bytes memory data
	) internal returns (TransparentUpgradeableProxy instance) {
		bytes memory args = abi.encode(implementation, admin, data);
		bytes memory initCode = abi.encodePacked(getCode("TransparentUpgradeableProxy"), args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(address(instance), string.concat(name, " Proxy"));
	}

	function create2(bytes32 salt, string memory name) internal returns (address instance) {
		return create2(salt, name, "");
	}

	function create2(bytes32 salt, string memory name, bytes memory args) internal returns (address instance) {
		bytes memory initCode = abi.encodePacked(getCode(name), args);

		assembly ("memory-safe") {
			instance := create2(0x00, add(initCode, 0x20), mload(initCode), salt)
			if iszero(instance) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		label(instance, name);
	}

	function computeAddress(
		string memory name,
		bytes32 salt,
		address deployer
	) internal view returns (address instance) {
		return computeAddress(name, "", salt, deployer);
	}

	function computeAddress(
		string memory name,
		bytes memory args,
		bytes32 salt,
		address deployer
	) internal view returns (address instance) {
		bytes memory initCode = abi.encodePacked(getCode(name), args);
		return computeAddress(keccak256(initCode), salt, deployer);
	}

	function computeAddress(bytes32 hash, bytes32 salt, address deployer) internal pure returns (address instance) {
		assembly ("memory-safe") {
			mstore8(0x00, 0xff)
			mstore(0x35, hash)
			mstore(0x01, shl(0x60, deployer))
			mstore(0x15, salt)
			instance := keccak256(0x00, 0x55)
			mstore(0x35, 0x00)
		}
	}

	function getCode(string memory name) internal view returns (bytes memory) {
		return vm.getCode(string.concat(name, ".sol:", name));
	}

	function label(address instance, string memory name) internal {
		if (vm.isContext(VmSafe.ForgeContext.Test)) vm.label(instance, name);
	}
}
