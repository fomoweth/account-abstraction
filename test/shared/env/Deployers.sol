// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {BootstrapLib, BootstrapConfig} from "src/libraries/BootstrapLib.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleTypeLib, ModuleType} from "src/types/ModuleType.sol";

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

import {MockExecutor} from "test/shared/mocks/MockExecutor.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {MockValidator} from "test/shared/mocks/MockValidator.sol";

import {Attester} from "test/shared/structs/Attester.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {Deploy} from "test/shared/utils/Deploy.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

import {Configured} from "config/Configured.sol";
import {Constants} from "./Constants.sol";

abstract contract Deployers is Test, Configured, Constants {
	using Arrays for address[];
	using BootstrapLib for address;
	using BootstrapLib for BootstrapConfig;
	using Deploy for bytes32;
	using Deploy for ModuleFactory;
	using ModuleTypeLib for ModuleType[];
	using SolArray for *;

	bytes32 internal constant SALT = 0x0000000000000000000000000000000000000000000000000000000000007579;
	bytes32 internal constant RESOLVER_UID = 0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f;

	uint256 internal constant INITIAL_BALANCE = 1000 ether;
	uint256 internal constant INITIAL_VALUE = 100 ether;
	uint256 internal constant DEFAULT_VALUE = 10 ether;
	uint32 internal constant DEFAULT_STAKE_DELAY = 1 weeks;

	MockValidator internal MOCK_VALIDATOR;
	MockExecutor internal MOCK_EXECUTOR;
	MockFallback internal MOCK_FALLBACK;
	MockHook internal MOCK_HOOK;

	K1Validator internal K1_VALIDATOR;
	Permit2Executor internal PERMIT2_EXECUTOR;
	UniversalExecutor internal UNIVERSAL_EXECUTOR;
	NativeWrapper internal NATIVE_WRAPPER;
	STETHWrapper internal STETH_WRAPPER;

	ModuleFactory internal MODULE_FACTORY;
	MetaFactory internal META_FACTORY;
	AccountFactory internal ACCOUNT_FACTORY;
	K1ValidatorFactory internal K1_FACTORY;
	RegistryFactory internal REGISTRY_FACTORY;

	Bootstrap internal BOOTSTRAP;
	Vortex internal VORTEX;

	Attester[] internal ATTESTERS;
	address[] internal ATTESTER_ADDRESSES;
	uint8 internal THRESHOLD = 1;

	Signer internal ADMIN;
	Signer internal BUNDLER;

	Signer internal ALICE;
	Signer internal COOPER;
	Signer internal MURPHY;

	modifier impersonate(Signer memory signer, bool asAccount) {
		vm.startPrank(asAccount ? address(signer.account) : signer.eoa);
		_;
		vm.stopPrank();
	}

	function setUpAccounts() internal virtual {
		deployVortex(ALICE, 0, address(K1_FACTORY), true);
		deployVortex(COOPER, 0, address(REGISTRY_FACTORY), true);
		deployVortex(MURPHY, 0, address(ACCOUNT_FACTORY), false);
	}

	function setUpSigners() internal virtual {
		ADMIN = createSigner("Admin", "", 0, 0);
		BUNDLER = createSigner("Bundler", "", 100 ether, 10 ether);
		ALICE = createSigner("Alice", "wonderland", 0, 0);
		COOPER = createSigner("Cooper", "gargantua", 0, 0);
		MURPHY = createSigner("Murphy", "gravity.eq", 0, 0);

		(ATTESTERS, ATTESTER_ADDRESSES) = createAttesters(THRESHOLD + 1);
	}

	function setUpContracts() internal virtual {
		labelContracts();
		deployContracts();
		setUpFactories();
	}

	function labelContracts() internal virtual {
		labelCurrencies();
		vm.label(address(ENTRYPOINT), "EntryPoint");
		vm.label(address(REGISTRY), "Registry");
		vm.label(address(SMART_SESSION), "SmartSession");
		vm.label(address(PERMIT2), "Permit2");
	}

	function deployContracts() internal virtual impersonate(ADMIN, false) {
		label(address(META_FACTORY = SALT.metaFactory(ADMIN.eoa)), "MetaFactory");
		label(address(VORTEX = SALT.vortex()), "VortexImplementation");
		label(address(BOOTSTRAP = SALT.bootstrap()), "Bootstrap");
		deployModules();
		deployFactories();
	}

	function deployVortex(
		Signer storage signer,
		uint16 id,
		address factory,
		bool useRegistry
	) internal virtual returns (Vortex) {
		bytes32 salt = signer.encodeSalt(id);
		address payable account = META_FACTORY.computeAddress(factory, salt);
		vm.assertTrue(account != address(0) && account.code.length == 0);

		bytes memory initCode = getAccountInitCode(signer.eoa, salt, factory, true, useRegistry);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(account, initCode, address(K1_VALIDATOR));

		ENTRYPOINT.depositTo{value: INITIAL_VALUE}(account);
		ENTRYPOINT.handleOps(userOps, signer.eoa);

		vm.assertEq((signer.account = Vortex(account)).rootValidator(), address(K1_VALIDATOR));
		vm.assertEq(K1_VALIDATOR.getAccountOwner(account), signer.eoa);
		vm.label(account, string.concat(vm.getLabel(signer.eoa), " Vortex"));

		return signer.account;
	}

	function getAccountInitCode(
		address owner,
		bytes32 salt,
		address factory,
		bool useMetaFactory,
		bool useRegistry
	) internal view virtual returns (bytes memory initCode) {
		vm.assertTrue(META_FACTORY.isAuthorized(factory));

		address registry;
		address[] memory attesters;
		uint8 threshold;

		if (useRegistry) {
			registry = address(REGISTRY);
			attesters = ATTESTER_ADDRESSES;
			threshold = THRESHOLD;
		}

		bytes memory params;

		if (factory == address(ACCOUNT_FACTORY)) {
			BootstrapConfig memory rootValidator = address(K1_VALIDATOR).build(
				TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR),
				abi.encodePacked(owner, BUNDLER.eoa, PERMIT2),
				""
			);

			bytes memory initializer = BOOTSTRAP.getInitializeScopedCalldata(
				rootValidator,
				registry,
				attesters,
				threshold
			);

			params = abi.encodeCall(Vortex.initializeAccount, (initializer));
		} else if (factory == address(REGISTRY_FACTORY)) {
			BootstrapConfig memory rootValidator = address(K1_VALIDATOR).build(
				TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR),
				abi.encodePacked(owner, BUNDLER.eoa, PERMIT2),
				""
			);

			BootstrapConfig[] memory validators = address(MOCK_VALIDATOR)
				.build(TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR), abi.encodePacked(owner), "")
				.arrayify();

			BootstrapConfig[] memory executors = address(MOCK_EXECUTOR).build(TYPE_EXECUTOR, "", "").arrayify();

			bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
				MOCK_FALLBACK.fallbackDelegate.selector,
				MOCK_FALLBACK.fallbackStatic.selector,
				MOCK_FALLBACK.fallbackSuccess.selector
			);

			CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
				CALLTYPE_DELEGATE,
				CALLTYPE_STATIC,
				CALLTYPE_STATIC
			);

			bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

			BootstrapConfig[] memory fallbacks = address(MOCK_FALLBACK)
				.build(TYPE_FALLBACK.moduleTypes(), abi.encode(configurations, ""), "")
				.arrayify();

			BootstrapConfig[] memory hooks = address(MOCK_HOOK).build(TYPE_HOOK, vm.randomBytes(32), "").arrayify();

			params = abi.encode(rootValidator, validators, executors, fallbacks, hooks);
		} else if (factory == address(K1_FACTORY)) {
			params = abi.encode(owner, BUNDLER.eoa.addresses(address(PERMIT2)), registry, attesters, threshold);
		} else {
			revert("invalid factory");
		}

		initCode = abi.encodePacked(factory, abi.encodeCall(AccountFactory.createAccount, (salt, params)));

		if (useMetaFactory) {
			initCode = abi.encodePacked(META_FACTORY, abi.encodeCall(MetaFactory.createAccount, (initCode)));
		}
	}

	function deployFactories() internal virtual {
		label(address(ACCOUNT_FACTORY = SALT.accountFactory(address(VORTEX))), "AccountFactory");

		label(
			address(K1_FACTORY = SALT.k1ValidatorFactory(address(VORTEX), address(BOOTSTRAP), address(K1_VALIDATOR))),
			"K1ValidatorFactory"
		);

		label(
			address(
				REGISTRY_FACTORY = SALT.registryFactory(
					address(VORTEX),
					address(BOOTSTRAP),
					address(REGISTRY),
					ADMIN.eoa
				)
			),
			"RegistryFactory"
		);
	}

	function setUpFactories() internal virtual impersonate(ADMIN, false) {
		META_FACTORY.addStake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_STAKE_DELAY);
		META_FACTORY.authorize(address(ACCOUNT_FACTORY));
		META_FACTORY.authorize(address(K1_FACTORY));
		META_FACTORY.authorize(address(REGISTRY_FACTORY));
		REGISTRY_FACTORY.configureAttesters(ATTESTER_ADDRESSES, THRESHOLD);
	}

	function deployModules() internal virtual {
		MODULE_FACTORY = Deploy.moduleFactory(SALT, address(REGISTRY), RESOLVER_UID);

		uint256 length = isEthereum() ? 5 : 4;
		address[] memory modules = new address[](length);
		ModuleType[][] memory moduleTypeIds = new ModuleType[][](length);

		modules[0] = label(address(K1_VALIDATOR = MODULE_FACTORY.k1Validator(SALT)), "K1Validator");
		moduleTypeIds[0] = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		modules[1] = label(address(PERMIT2_EXECUTOR = MODULE_FACTORY.permit2Executor(SALT)), "Permit2Executor");
		moduleTypeIds[1] = TYPE_EXECUTOR.moduleTypes();

		modules[2] = label(
			address(UNIVERSAL_EXECUTOR = MODULE_FACTORY.universalExecutor(SALT, WNATIVE.toAddress())),
			"UniversalExecutor"
		);
		moduleTypeIds[2] = TYPE_EXECUTOR.moduleTypes();

		modules[3] = label(
			address(NATIVE_WRAPPER = MODULE_FACTORY.nativeWrapper(SALT, WNATIVE.toAddress())),
			"NativeWrapper"
		);
		moduleTypeIds[3] = TYPE_FALLBACK.moduleTypes();

		if (length == 5) {
			modules[4] = label(
				address(STETH_WRAPPER = MODULE_FACTORY.stETHWrapper(SALT, STETH.toAddress(), WSTETH.toAddress())),
				"STETHWrapper"
			);
			moduleTypeIds[4] = TYPE_FALLBACK.moduleTypes();
		}

		for (uint256 i; i < ATTESTERS.length; ++i) {
			ATTESTERS[i].attest(modules, moduleTypeIds);
		}

		deployMockModules();
	}

	function deployMockModules() internal virtual {
		MOCK_VALIDATOR = MockValidator(
			deployModule("MockValidator", "", TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR))
		);

		MOCK_EXECUTOR = MockExecutor(deployModule("MockExecutor", "", TYPE_EXECUTOR.moduleTypes()));

		MOCK_FALLBACK = MockFallback(deployModule("MockFallback", "", TYPE_FALLBACK.moduleTypes()));

		MOCK_HOOK = MockHook(deployModule("MockHook", "", TYPE_HOOK.moduleTypes()));
	}

	function deployModule(
		string memory name,
		bytes memory args,
		ModuleType[] memory moduleTypeIds
	) internal virtual returns (address module) {
		bytes memory bytecode = vm.getCode(string.concat(name, ".sol:", name));
		vm.label((module = MODULE_FACTORY.deployModule(SALT, bytecode, args)), name);

		for (uint256 i; i < ATTESTERS.length; ++i) {
			ATTESTERS[i].attest(module, moduleTypeIds);
		}
	}

	function createSigner(
		string memory name,
		bytes10 keyword,
		uint256 deposit,
		uint256 stake
	) internal virtual returns (Signer memory signer) {
		signer.privateKey = encodePrivateKey(name);
		(signer.publicKeyX, signer.publicKeyY) = vm.publicKeyP256(signer.privateKey);
		signer.eoa = payable(vm.addr(signer.privateKey));
		signer.keyword = keyword;

		vm.deal(signer.eoa, INITIAL_BALANCE + deposit + stake);
		vm.label(signer.eoa, name);

		if (deposit != 0) signer.addDeposit(deposit, signer.eoa);
		if (stake != 0) signer.addStake(stake, DEFAULT_STAKE_DELAY);
	}

	function createAttesters(
		uint256 length
	) internal virtual returns (Attester[] memory attesters, address[] memory addresses) {
		string memory prefix = "Attester";
		uint256 key = encodePrivateKey(prefix);

		attesters = new Attester[](length);
		addresses = new address[](length);

		for (uint256 i; i < length; ++i) {
			vm.deal(
				addresses[i] = attesters[i].eoa = payable(vm.addr(attesters[i].privateKey = key + i)),
				INITIAL_BALANCE
			);
		}

		addresses.insertionSort();
		addresses.uniquifySorted();

		for (uint256 i; i < length; ++i) {
			vm.label(addresses[i], string.concat(prefix, " #", vm.toString(i)));

			for (uint256 j = i; j < length; ++j) {
				if (attesters[j].eoa == addresses[i]) {
					Attester memory attester = attesters[j];
					attesters[j] = attesters[i];
					attesters[i] = attester;
					break;
				}
			}
		}
	}

	function encodePrivateKey(string memory key) internal pure virtual returns (uint256 privateKey) {
		return boundPrivateKey(uint256(keccak256(abi.encodePacked(key))));
	}

	function encodeInstallModuleParams(
		ModuleType[] memory moduleTypeIds,
		bytes memory data,
		bytes memory hookData
	) internal pure virtual returns (bytes memory result) {
		result = abi.encodePacked(
			moduleTypeIds.encode(),
			bytes4(uint32(data.length)),
			data,
			bytes4(uint32(hookData.length)),
			hookData
		);
	}

	function encodeUninstallModuleParams(
		bytes memory data,
		bytes memory hookData
	) internal pure virtual returns (bytes memory result) {
		result = abi.encodePacked(bytes4(uint32(data.length)), data, bytes4(uint32(hookData.length)), hookData);
	}

	function encodeFallbackSelectors(
		bytes4[] memory selectors,
		CallType[] memory callTypes
	) internal pure virtual returns (bytes32[] memory configurations) {
		uint256 length = selectors.length;
		configurations = new bytes32[](length);

		for (uint256 i; i < length; ++i) {
			configurations[i] = bytes32(abi.encodePacked(selectors[i], callTypes[i]));
		}
	}
}
