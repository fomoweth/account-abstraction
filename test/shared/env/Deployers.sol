// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console2 as console} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {Configured} from "config/Configured.sol";

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {Arrays} from "src/libraries/Arrays.sol";
import {BootstrapLib, BootstrapConfig} from "src/libraries/BootstrapLib.sol";
import {ExecutionLib, Execution} from "src/libraries/ExecutionLib.sol";

import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";

import {K1Validator} from "src/modules/validators/K1Validator.sol";

import {Bootstrap} from "src/Bootstrap.sol";

import {AccountFactory, IAccountFactory} from "src/factories/AccountFactory.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {VortexFactory} from "src/factories/VortexFactory.sol";

import {Vortex} from "src/Vortex.sol";

import {MockExecutor} from "test/shared/mocks/MockExecutor.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {MockValidator} from "test/shared/mocks/MockValidator.sol";

import {AttestationUtils, AttestationRequest} from "test/shared/utils/AttestationUtils.sol";
import {MulticallUtils} from "test/shared/utils/MulticallUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

import {Common} from "./Common.sol";
import {User} from "./User.sol";

abstract contract Deployers is Configured, Common, StdUtils {
	using Arrays for address[];
	using BootstrapLib for address;
	using BootstrapLib for BootstrapConfig;
	using ModuleTypeLib for ModuleType[];
	using SolArray for address;
	using SolArray for bytes1;
	using SolArray for bytes4;
	using SolArray for ModuleType;

	error CreateDeploymentFailed();
	error Create2DeploymentFailed();

	MetaFactory internal META_FACTORY;
	AccountFactory internal ACCOUNT_FACTORY;
	RegistryFactory internal REGISTRY_FACTORY;
	VortexFactory internal VORTEX_FACTORY;

	Bootstrap internal BOOTSTRAP;

	K1Validator internal K1_VALIDATOR;

	MockValidator internal MOCK_VALIDATOR;
	MockExecutor internal MOCK_EXECUTOR;
	MockFallback internal MOCK_FALLBACK;
	MockHook internal MOCK_HOOK;

	Vortex internal ACCOUNT_IMPLEMENTATION;
	Vortex internal ALICE_ACCOUNT;
	Vortex internal BOB_ACCOUNT;
	Vortex internal COOPER_ACCOUNT;

	User internal ALICE;
	User internal BOB;
	User internal COOPER;
	User internal MURPHY;

	address payable internal ALICE_ADDRESS;
	address payable internal BOB_ADDRESS;
	address payable internal COOPER_ADDRESS;
	address payable internal MURPHY_ADDRESS;

	User internal DEPLOYER;
	User internal ADMIN;
	User internal BUNDLER;
	User internal BENEFICIARY;

	address payable internal DEPLOYER_ADDRESS;
	address payable internal ADMIN_ADDRESS;
	address payable internal BUNDLER_ADDRESS;
	address payable internal BENEFICIARY_ADDRESS;

	uint8 internal THRESHOLD = 1;

	User[] internal ATTESTERS;
	address[] internal ATTESTER_ADDRESSES;
	uint256 internal ATTESTERS_COUNT = THRESHOLD + 1;

	User[] internal SENDERS;
	address[] internal SENDER_ADDRESSES;
	uint256 internal SENDERS_COUNT = 3;

	uint256 internal constant INITIAL_BALANCE = 1000 ether;
	uint256 internal constant INITIAL_VALUE = 10 ether;

	bytes1 internal constant INITIALIZER_DEFAULT = 0x00;
	bytes1 internal constant INITIALIZER_SCOPED = 0x01;
	bytes1 internal constant INITIALIZER_ROOT = 0x02;

	bytes1 internal initializerFlag = INITIALIZER_DEFAULT;

	modifier impersonate(address account) {
		vm.startPrank(account);
		_;
		vm.stopPrank();
	}

	function setInitializerFlag(bytes1 flag) internal virtual {
		vm.assume(flag <= INITIALIZER_ROOT);
		initializerFlag = flag;
	}

	function setUpAccounts() internal virtual {
		ALICE_ACCOUNT = deployAccount("ALICE_ACCOUNT", ALICE, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), true);
		BOB_ACCOUNT = deployAccount("BOB_ACCOUNT", BOB, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), true);
		COOPER_ACCOUNT = deployAccount("COOPER_ACCOUNT", COOPER, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), true);
	}

	function setUpContracts() internal virtual {
		deployContracts();
		setUpModules();
		setUpFactories();
	}

	function deployContracts() internal virtual {
		deployAccountImplementation();
		deployBootstrap();
		deployModules();
		deployFactories();
	}

	function deployAccount(
		string memory name,
		User memory user,
		uint256 index,
		uint256 value,
		address factory,
		bool useMetaFactory
	) internal virtual impersonate(user.addr) returns (Vortex) {
		(address payable account, bytes memory initCode, ) = getAccountAndInitCode(user, index, factory, true);

		if (useMetaFactory) {
			initCode = abi.encodePacked(META_FACTORY, abi.encodeCall(META_FACTORY.createAccount, (initCode)));
		}

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		userOps[0] = user.buildUserOp(account, initCode, emptyBytes(), emptyBytes(), address(K1_VALIDATOR));

		ENTRYPOINT.depositTo{value: value}(account);
		ENTRYPOINT.handleOps(userOps, user.addr);

		vm.assertEq(Vortex(account).rootValidator(), address(K1_VALIDATOR));
		vm.assertEq(K1_VALIDATOR.getAccountOwner(account), user.addr);
		vm.assertEq(K1_VALIDATOR.getSafeSenders(account), SENDER_ADDRESSES);

		vm.label(account, name);

		return Vortex(account);
	}

	function getAccountAndInitCode(
		User memory user,
		uint256 index,
		address factory,
		bool appendFactory
	) internal virtual returns (address payable account, bytes memory initCode, bytes32 salt) {
		salt = encodeSalt(user.addr, index);

		while (isContract((account = IAccountFactory(factory).computeAddress(salt)))) {
			salt = encodeSalt(user.addr, ++index);
		}

		if (factory == address(VORTEX_FACTORY)) {
			initCode = abi.encode(user.addr, SENDER_ADDRESSES, ATTESTER_ADDRESSES, THRESHOLD);
		} else {
			BootstrapConfig memory rootValidator = address(K1_VALIDATOR).build(
				TYPE_VALIDATOR,
				TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR),
				abi.encode(user.addr, SENDER_ADDRESSES),
				emptyBytes()
			);

			BootstrapConfig memory hook = address(MOCK_HOOK).build(
				TYPE_HOOK,
				TYPE_HOOK.moduleTypes(),
				emptyBytes(),
				emptyBytes()
			);

			BootstrapConfig[] memory validators = address(MOCK_VALIDATOR)
				.build(
					TYPE_VALIDATOR,
					TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR),
					abi.encode(user.addr),
					emptyBytes()
				)
				.arrayify();

			BootstrapConfig[] memory executors = address(MOCK_EXECUTOR)
				.build(TYPE_EXECUTOR, TYPE_EXECUTOR.moduleTypes(), emptyBytes(), emptyBytes())
				.arrayify();

			(bytes4[] memory selectors, CallType[] memory callTypes) = MOCK_FALLBACK.getSupportedCalls();

			BootstrapConfig[] memory fallbacks = address(MOCK_FALLBACK)
				.build(
					TYPE_FALLBACK,
					TYPE_FALLBACK.moduleTypes(TYPE_EXECUTOR),
					abi.encode(selectors, callTypes, emptyBytes()),
					abi.encodePacked(MOCK_HOOK, emptyBytes())
				)
				.arrayify();

			bytes memory initializer;

			if (factory == address(REGISTRY_FACTORY) || initializerFlag == INITIALIZER_DEFAULT) {
				initializer = BOOTSTRAP.getInitializeCalldata(
					rootValidator,
					hook,
					validators,
					executors,
					fallbacks,
					address(REGISTRY),
					ATTESTER_ADDRESSES,
					THRESHOLD
				);
			} else if (initializerFlag == INITIALIZER_SCOPED) {
				initializer = BOOTSTRAP.getInitializeScopedCalldata(
					rootValidator,
					hook,
					address(REGISTRY),
					ATTESTER_ADDRESSES,
					THRESHOLD
				);
			} else if (initializerFlag == INITIALIZER_ROOT) {
				hook = SENTINEL.build(TYPE_HOOK, TYPE_HOOK.moduleTypes(), emptyBytes(), emptyBytes());

				initializer = BOOTSTRAP.getInitializeScopedCalldata(
					rootValidator,
					hook,
					address(REGISTRY),
					ATTESTER_ADDRESSES,
					THRESHOLD
				);
			}

			initCode = abi.encodeCall(Vortex.initializeAccount, (initializer));
		}

		if (appendFactory) {
			initCode = abi.encodePacked(factory, abi.encodeCall(IAccountFactory.createAccount, (salt, initCode)));
		}
	}

	function deployAccountImplementation() internal virtual impersonate(DEPLOYER_ADDRESS) {
		ACCOUNT_IMPLEMENTATION = Vortex(
			payable(create2("AccountImplementation", type(Vortex).creationCode, encodeSalt("Vortex V1")))
		);
	}

	function deployFactories() internal virtual impersonate(DEPLOYER_ADDRESS) {
		META_FACTORY = MetaFactory(
			payable(
				create2(
					"MetaFactory",
					bytes.concat(type(MetaFactory).creationCode, abi.encode(ADMIN_ADDRESS)),
					encodeSalt("MetaFactory")
				)
			)
		);

		ACCOUNT_FACTORY = AccountFactory(
			create2(
				"AccountFactory",
				bytes.concat(type(AccountFactory).creationCode, abi.encode(ACCOUNT_IMPLEMENTATION)),
				encodeSalt("AccountFactory")
			)
		);

		VORTEX_FACTORY = VortexFactory(
			create2(
				"VortexFactory",
				bytes.concat(
					type(VortexFactory).creationCode,
					abi.encode(ACCOUNT_IMPLEMENTATION, K1_VALIDATOR, BOOTSTRAP, REGISTRY)
				),
				encodeSalt("VortexFactory")
			)
		);

		REGISTRY_FACTORY = RegistryFactory(
			create2(
				"RegistryFactory",
				bytes.concat(
					type(RegistryFactory).creationCode,
					abi.encode(ACCOUNT_IMPLEMENTATION, REGISTRY, ATTESTER_ADDRESSES, THRESHOLD, ADMIN_ADDRESS)
				),
				encodeSalt("RegistryFactory")
			)
		);
	}

	function setUpFactories() internal virtual impersonate(ADMIN_ADDRESS) {
		META_FACTORY.depositTo{value: 50 ether}(address(ENTRYPOINT), address(META_FACTORY));

		META_FACTORY.setWhitelist(address(ACCOUNT_FACTORY), true);
		META_FACTORY.depositTo{value: 50 ether}(address(ENTRYPOINT), address(ACCOUNT_FACTORY));

		META_FACTORY.setWhitelist(address(VORTEX_FACTORY), true);
		META_FACTORY.depositTo{value: 50 ether}(address(ENTRYPOINT), address(VORTEX_FACTORY));

		META_FACTORY.setWhitelist(address(REGISTRY_FACTORY), true);
		META_FACTORY.depositTo{value: 50 ether}(address(ENTRYPOINT), address(REGISTRY_FACTORY));
	}

	function deployBootstrap() internal virtual impersonate(DEPLOYER_ADDRESS) {
		BOOTSTRAP = Bootstrap(create2("Bootstrap", type(Bootstrap).creationCode, encodeSalt("Bootstrap")));
	}

	function deployModules() internal virtual impersonate(DEPLOYER_ADDRESS) {
		K1_VALIDATOR = K1Validator(create2("K1Validator", type(K1Validator).creationCode, encodeSalt("K1Validator")));

		MOCK_VALIDATOR = MockValidator(
			create2("MockValidator", type(MockValidator).creationCode, encodeSalt("MockValidator"))
		);

		MOCK_EXECUTOR = MockExecutor(
			payable(create2("MockExecutor", type(MockExecutor).creationCode, encodeSalt("MockExecutor")))
		);

		MOCK_FALLBACK = MockFallback(
			create2("MockFallback", type(MockFallback).creationCode, encodeSalt("MockFallback"))
		);

		MOCK_HOOK = MockHook(create2("MockHook", type(MockHook).creationCode, encodeSalt("MockHook")));
	}

	function setUpModules() internal virtual impersonate(ADMIN_ADDRESS) {
		bytes[] memory payloads = new bytes[](5);

		payloads[0] = abi.encodeCall(
			REGISTRY.registerModule,
			(DEFAULT_RESOLVER_UID, address(K1_VALIDATOR), emptyBytes(), emptyBytes())
		);

		payloads[1] = abi.encodeCall(
			REGISTRY.registerModule,
			(DEFAULT_RESOLVER_UID, address(MOCK_VALIDATOR), emptyBytes(), emptyBytes())
		);

		payloads[2] = abi.encodeCall(
			REGISTRY.registerModule,
			(DEFAULT_RESOLVER_UID, address(MOCK_EXECUTOR), emptyBytes(), emptyBytes())
		);

		payloads[3] = abi.encodeCall(
			REGISTRY.registerModule,
			(DEFAULT_RESOLVER_UID, address(MOCK_FALLBACK), emptyBytes(), emptyBytes())
		);

		payloads[4] = abi.encodeCall(
			REGISTRY.registerModule,
			(DEFAULT_RESOLVER_UID, address(MOCK_HOOK), emptyBytes(), emptyBytes())
		);

		MulticallUtils.aggregate(MulticallUtils.build(address(REGISTRY), payloads));

		address[] memory modules = address(K1_VALIDATOR).addresses(
			address(MOCK_VALIDATOR),
			address(MOCK_EXECUTOR),
			address(MOCK_FALLBACK),
			address(MOCK_HOOK)
		);

		ModuleType[][] memory moduleTypeIds = new ModuleType[][](5);
		moduleTypeIds[0] = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);
		moduleTypeIds[1] = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);
		moduleTypeIds[2] = TYPE_EXECUTOR.moduleTypes();
		moduleTypeIds[3] = TYPE_FALLBACK.moduleTypes(TYPE_EXECUTOR);
		moduleTypeIds[4] = TYPE_HOOK.moduleTypes();

		AttestationRequest[] memory requests = AttestationUtils.build(modules, moduleTypeIds);

		for (uint256 i; i < ATTESTERS_COUNT; ++i) {
			User memory attester = ATTESTERS[i];
			uint256 nonce = REGISTRY.attesterNonce(attester.addr);

			bytes32 digest = REGISTRY.getDigest(requests, attester.addr);
			(uint8 v, bytes32 r, bytes32 s) = vm.sign(attester.privateKey, digest);
			bytes memory signature = abi.encodePacked(r, s, v);

			REGISTRY.attest(DEFAULT_SCHEMA_UID, attester.addr, requests, signature);

			vm.assertEq(REGISTRY.attesterNonce(attester.addr), nonce + 1);
		}
	}

	function create(string memory name, bytes memory bytecode) internal virtual returns (address instance) {
		vm.label((instance = create(bytecode)), name);
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
		bytes memory bytecode,
		bytes32 salt
	) internal virtual returns (address instance) {
		vm.label((instance = create2(bytecode, salt)), name);
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

	function etch(address target, address original) internal virtual {
		etch(target, original.code);
	}

	function etch(address target, bytes memory bytecode) internal virtual {
		vm.etch(target, bytecode);
	}

	function setUpUsers() internal virtual {
		(DEPLOYER, DEPLOYER_ADDRESS) = createUser("DEPLOYER", INITIAL_BALANCE);

		(ADMIN, ADMIN_ADDRESS) = createUser("ADMIN", INITIAL_BALANCE);

		(BUNDLER, BUNDLER_ADDRESS) = createUser("BUNDLER", INITIAL_BALANCE);

		(BENEFICIARY, BENEFICIARY_ADDRESS) = createUser("BENEFICIARY", 0);

		(ALICE, ALICE_ADDRESS) = createUser("ALICE", INITIAL_BALANCE);

		(BOB, BOB_ADDRESS) = createUser("BOB", INITIAL_BALANCE);

		(COOPER, COOPER_ADDRESS) = createUser("COOPER", INITIAL_BALANCE);

		(MURPHY, MURPHY_ADDRESS) = createUser("MURPHY", INITIAL_BALANCE);

		(ATTESTERS, ATTESTER_ADDRESSES) = createUsers("ATTESTER", ATTESTERS_COUNT, INITIAL_BALANCE);

		(SENDERS, SENDER_ADDRESSES) = createUsers("SENDER", SENDERS_COUNT, INITIAL_BALANCE);
	}

	function createUser(
		string memory name,
		uint256 value
	) internal virtual returns (User memory u, address payable addr) {
		(u, addr) = _createUser(encodePrivateKey(name), value);
		vm.label(addr, name);
	}

	function createUsers(
		string memory prefix,
		uint256 count,
		uint256 value
	) internal virtual returns (User[] memory users, address[] memory addresses) {
		users = new User[](count);
		addresses = new address[](count);

		uint256 privateKey = encodePrivateKey(prefix);

		for (uint256 i; i < count; ++i) {
			(users[i], addresses[i]) = _createUser(privateKey + i, value);
		}

		addresses.sort();

		for (uint256 i; i < count; ++i) {
			string memory name = string.concat(prefix, " #", vm.toString(i));
			vm.label(addresses[i], name);

			for (uint256 j = i; j < count; ++j) {
				if (users[j].addr == addresses[i]) {
					User memory user = users[i];
					users[i] = users[j];
					users[j] = user;
					break;
				}
			}
		}
	}

	function _createUser(uint256 privateKey, uint256 value) private returns (User memory u, address payable addr) {
		(u.publicKeyX, u.publicKeyY) = vm.publicKeyP256((u.privateKey = privateKey));
		vm.deal(u.addr = addr = payable(vm.addr(u.privateKey)), value);
	}

	function encodePrivateKey(string memory key) internal pure returns (uint256 privateKey) {
		return boundPrivateKey(uint256(keccak256(abi.encodePacked(key))));
	}

	function encodeSalt(string memory key) internal pure virtual returns (bytes32 salt) {
		return keccak256(abi.encodePacked(key));
	}

	function encodeSalt(address owner, uint256 index) internal pure virtual returns (bytes32 salt) {
		return keccak256(abi.encodePacked(owner, index));
	}
}
