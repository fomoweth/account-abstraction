// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ISmartAccountFactory} from "src/interfaces/factories/ISmartAccountFactory.sol";
import {ERC7739Validator} from "src/modules/validators/ERC7739Validator.sol";
import {Bootstrap, BootstrapConfig} from "src/Bootstrap.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {SmartAccountFactory} from "src/factories/SmartAccountFactory.sol";
import {SmartAccount} from "src/SmartAccount.sol";

import {MockMultiModule} from "test/shared/mocks/MockMultiModule.sol";
import {MockExecutor} from "test/shared/mocks/MockExecutor.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {MockRegistry} from "test/shared/mocks/MockRegistry.sol";
import {MockResolver} from "test/shared/mocks/MockResolver.sol";
import {MockSchemaValidator} from "test/shared/mocks/MockSchemaValidator.sol";

import {BootstrapUtils} from "test/shared/utils/BootstrapUtils.sol";
import {UserOperationUtils} from "test/shared/utils/UserOperationUtils.sol";

import {Configured} from "config/Configured.sol";
import {Common} from "./Common.sol";
import {Signers} from "./Signers.sol";

abstract contract Deployers is Configured, Common, Signers {
	using UserOperationUtils for Signer;

	MetaFactory internal META_FACTORY;
	SmartAccountFactory internal ACCOUNT_FACTORY;

	SmartAccount internal ACCOUNT_IMPLEMENTATION;
	SmartAccount internal ALICE_ACCOUNT;
	SmartAccount internal BOB_ACCOUNT;
	SmartAccount internal COOPER_ACCOUNT;

	MockRegistry internal MOCK_REGISTRY;

	MockResolver internal RESOLVER;
	MockSchemaValidator internal SCHEMA;

	Bootstrap internal BOOTSTRAP;

	MockMultiModule internal MULTI_MODULE;
	ERC7739Validator internal VALIDATOR;
	MockExecutor internal EXECUTOR;
	MockFallback internal FALLBACK;
	MockHook internal HOOK;

	bytes32 internal constant DEFAULT_RESOLVER_UID = 0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f;
	bytes32 internal constant DEFAULT_SCHEMA_UID = 0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1;
	string internal constant DEFAULT_SCHEMA = "FOMO";

	bytes32 internal constant DEFAULT_SALT = keccak256("1");
	uint256 internal constant INITIAL_DEPOSIT = 100 ether;

	function setUpAccounts() internal virtual {
		ALICE_ACCOUNT = deployAccount("ALICE_ACCOUNT", ALICE, DEFAULT_SALT, INITIAL_DEPOSIT);
		BOB_ACCOUNT = deployAccount("BOB_ACCOUNT", BOB, DEFAULT_SALT, INITIAL_DEPOSIT);
		COOPER_ACCOUNT = deployAccount("COOPER_ACCOUNT", COOPER, DEFAULT_SALT, INITIAL_DEPOSIT);
	}

	function setUpContracts() internal virtual {
		deployAccountImplementation();
		deployRegistry();
		deployFactories();
		deployModules();
	}

	function deployAccountImplementation() internal virtual impersonate(DEPLOYER_ADDRESS) {
		ACCOUNT_IMPLEMENTATION = SmartAccount(
			payable(create("SmartAccount Implementation", type(SmartAccount).creationCode))
		);
	}

	function deployFactories() internal virtual impersonate(DEPLOYER_ADDRESS) {
		META_FACTORY = MetaFactory(create("MetaFactory", type(MetaFactory).creationCode, abi.encode(DEPLOYER_ADDRESS)));

		ACCOUNT_FACTORY = SmartAccountFactory(
			create("SmartAccountFactory", type(SmartAccountFactory).creationCode, abi.encode(ACCOUNT_IMPLEMENTATION))
		);
	}

	function deployRegistry() internal virtual impersonate(DEPLOYER_ADDRESS) {
		MOCK_REGISTRY = MockRegistry(create("MockRegistry", type(MockRegistry).creationCode));
	}

	function deployModules() internal virtual impersonate(DEPLOYER_ADDRESS) {
		BOOTSTRAP = Bootstrap(create("Bootstrap", type(Bootstrap).creationCode));

		MULTI_MODULE = MockMultiModule(create("MockMultiModule", type(MockMultiModule).creationCode));

		VALIDATOR = ERC7739Validator(create("ERC7739Validator", type(ERC7739Validator).creationCode));

		EXECUTOR = MockExecutor(payable(create("MockExecutor", type(MockExecutor).creationCode)));

		FALLBACK = MockFallback(create("MockFallback", type(MockFallback).creationCode));

		HOOK = MockHook(create("MockHook", type(MockHook).creationCode));
	}

	function deployAccount(
		string memory name,
		Signer memory signer,
		bytes32 salt,
		uint256 value
	) internal virtual impersonate(signer.addr) returns (SmartAccount) {
		(address payable account, bytes memory initCode) = getAccountAndInitCode(signer, salt);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.buildUserOpWithInitCode(account, initCode, address(VALIDATOR));

		ENTRYPOINT.depositTo{value: value}(account);
		ENTRYPOINT.handleOps(userOps, payable(signer.addr));

		vm.assertTrue(VALIDATOR.getOwner(account) == signer.addr);
		vm.label(account, name);

		return SmartAccount(account);
	}

	function deployAccount(
		string memory name,
		Signer memory signer,
		bytes32 salt,
		uint256 value,
		address factory
	) internal virtual impersonate(signer.addr) returns (SmartAccount) {
		(address payable account, bytes memory initCode) = getAccountAndInitCode(signer, salt, factory);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = signer.buildUserOpWithInitCode(account, initCode, address(VALIDATOR));

		ENTRYPOINT.depositTo{value: value}(account);
		ENTRYPOINT.handleOps(userOps, payable(signer.addr));

		vm.assertTrue(VALIDATOR.getOwner(account) == signer.addr);
		vm.label(account, name);

		return SmartAccount(account);
	}

	function getAccountAndInitCode(
		Signer memory signer,
		bytes32 salt
	) internal view virtual returns (address payable account, bytes memory initCode) {
		BootstrapConfig[] memory validators = BootstrapUtils.build(
			address(VALIDATOR),
			abi.encode(signer.addr),
			MODULE_TYPE_VALIDATOR
		);

		BootstrapConfig[] memory executors = BootstrapUtils.build(
			address(EXECUTOR),
			emptyBytes(),
			MODULE_TYPE_EXECUTOR
		);

		BootstrapConfig[] memory fallbacks = BootstrapUtils.build(
			address(FALLBACK),
			emptyBytes(),
			MODULE_TYPE_FALLBACK
		);

		BootstrapConfig memory hook = BootstrapUtils.get(address(HOOK), emptyBytes(), MODULE_TYPE_HOOK);

		bytes memory data = BOOTSTRAP.getInitializeCalldata(
			validators,
			executors,
			fallbacks,
			hook,
			address(MOCK_REGISTRY),
			ATTESTERS,
			THRESHOLD
		);

		account = ACCOUNT_FACTORY.computeAddress(data, salt);

		bytes memory callData = abi.encodeCall(ACCOUNT_FACTORY.createAccount, (data, salt));
		initCode = abi.encodePacked(ACCOUNT_FACTORY, callData);
	}

	function getAccountAndInitCode(
		Signer memory signer,
		bytes32 salt,
		address factory
	) internal view virtual returns (address payable account, bytes memory initCode) {
		BootstrapConfig[] memory validators = BootstrapUtils.build(
			address(VALIDATOR),
			abi.encode(signer.addr),
			MODULE_TYPE_VALIDATOR
		);

		BootstrapConfig[] memory executors = BootstrapUtils.build(
			address(EXECUTOR),
			emptyBytes(),
			MODULE_TYPE_EXECUTOR
		);

		BootstrapConfig[] memory fallbacks = BootstrapUtils.build(
			address(FALLBACK),
			emptyBytes(),
			MODULE_TYPE_FALLBACK
		);

		BootstrapConfig memory hook = BootstrapUtils.get(address(HOOK), emptyBytes(), MODULE_TYPE_HOOK);

		bytes memory data = BOOTSTRAP.getInitializeCalldata(
			validators,
			executors,
			fallbacks,
			hook,
			address(MOCK_REGISTRY),
			ATTESTERS,
			THRESHOLD
		);

		account = ISmartAccountFactory(factory).computeAddress(data, salt);

		bytes memory callData = abi.encodeCall(ISmartAccountFactory.createAccount, (data, salt));
		initCode = abi.encodePacked(factory, callData);
	}

	function create(
		string memory name,
		bytes memory creationCode,
		bytes memory constructorArgs
	) internal virtual returns (address instance) {
		return create(name, abi.encodePacked(creationCode, constructorArgs));
	}

	function create(string memory name, bytes memory bytecode) internal virtual returns (address instance) {
		label((instance = create(bytecode)), name);
	}

	function create(bytes memory bytecode) internal virtual returns (address instance) {
		assembly ("memory-safe") {
			instance := create(0x00, add(bytecode, 0x20), mload(bytecode))

			if iszero(extcodesize(instance)) {
				mstore(0x00, 0x2c2b8fb3) // CreateDeploymentFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	function create2(
		string memory name,
		bytes memory creationCode,
		bytes memory constructorArgs,
		bytes32 salt
	) internal virtual returns (address instance) {
		return create2(name, abi.encodePacked(creationCode, constructorArgs), salt);
	}

	function create2(
		string memory name,
		bytes memory bytecode,
		bytes32 salt
	) internal virtual returns (address instance) {
		label((instance = create2(bytecode, salt)), name);
	}

	function create2(bytes memory bytecode, bytes32 salt) internal virtual returns (address instance) {
		assembly ("memory-safe") {
			instance := create2(0x00, add(bytecode, 0x20), mload(bytecode), salt)

			if iszero(extcodesize(instance)) {
				mstore(0x00, 0x34bf4559) // Create2DeploymentFailed()
				revert(0x1c, 0x04)
			}
		}
	}
}
