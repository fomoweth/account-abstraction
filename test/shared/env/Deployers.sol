// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {BootstrapLib, BootstrapConfig} from "src/libraries/BootstrapLib.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";

import {Permit2Executor} from "src/modules/executors/Permit2Executor.sol";
import {UniversalExecutor} from "src/modules/executors/UniversalExecutor.sol";
import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";

import {AccountFactory} from "src/factories/AccountFactory.sol";
import {MetaFactory} from "src/factories/MetaFactory.sol";
import {RegistryFactory} from "src/factories/RegistryFactory.sol";
import {K1ValidatorFactory} from "src/factories/K1ValidatorFactory.sol";

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
	using ModuleTypeLib for ModuleType[];
	using SolArray for *;

	bytes32 internal constant SALT = 0x0000000000000000000000000000000000000000000000000000000000007579;

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
		deployVortex(ALICE, 0, INITIAL_VALUE, address(K1_FACTORY), true);
		deployVortex(COOPER, 0, INITIAL_VALUE, address(REGISTRY_FACTORY), true);
		deployVortex(MURPHY, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), false);
	}

	function setUpSigners() internal virtual {
		ADMIN = createSigner("Admin", "");
		BUNDLER = createSigner("Bundler", "", INITIAL_BALANCE, 100 ether, 10 ether);

		ALICE = createSigner("Alice", "wonderland");
		COOPER = createSigner("Cooper", "gargantua");
		MURPHY = createSigner("Murphy", "gravity.eq");

		(ATTESTERS, ATTESTER_ADDRESSES) = createAttesters("Attester", THRESHOLD + 1, INITIAL_BALANCE);
	}

	function setUpContracts() internal virtual {
		labelContracts();
		deployContracts();
		setUpFactories();
	}

	function labelContracts() internal virtual {
		vm.label(address(ENTRYPOINT), "EntryPoint");
		vm.label(address(REGISTRY), "Registry");
		vm.label(address(SMART_SESSION), "SmartSession");
		vm.label(address(PERMIT2), "Permit2");
		labelCurrencies();
	}

	function deployContracts() internal virtual impersonate(ADMIN, false) {
		META_FACTORY = Deploy.metaFactory(SALT, ADMIN.eoa);
		META_FACTORY.addStake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_STAKE_DELAY);

		VORTEX = Deploy.vortex(SALT);
		BOOTSTRAP = Deploy.bootstrap(SALT);

		deployModules();
		deployFactories();
	}

	function deployVortex(
		Signer storage signer,
		uint16 id,
		uint256 value,
		address factory,
		bool useRegistry
	) internal virtual returns (Vortex) {
		bytes32 salt = signer.encodeSalt(id);
		address payable account = META_FACTORY.computeAddress(factory, salt);
		vm.assertEq(account.code.length, 0);

		bytes memory initCode = getAccountInitCode(signer.eoa, salt, factory, true, useRegistry);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(account, initCode, address(K1_VALIDATOR));

		ENTRYPOINT.depositTo{value: value}(account);
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
		ACCOUNT_FACTORY = Deploy.accountFactory(SALT, address(VORTEX));

		K1_FACTORY = Deploy.k1ValidatorFactory(SALT, address(VORTEX), address(BOOTSTRAP), address(K1_VALIDATOR));

		REGISTRY_FACTORY = Deploy.registryFactory(
			SALT,
			address(VORTEX),
			address(BOOTSTRAP),
			address(REGISTRY),
			ADMIN.eoa
		);
	}

	function setUpFactories() internal virtual impersonate(ADMIN, false) {
		META_FACTORY.authorize(address(ACCOUNT_FACTORY));
		META_FACTORY.authorize(address(REGISTRY_FACTORY));
		META_FACTORY.authorize(address(K1_FACTORY));

		REGISTRY_FACTORY.configureAttesters(ATTESTER_ADDRESSES, THRESHOLD);
	}

	function deployModules() internal virtual {
		deployValidators();
		deployExecutors();
		deployFallbacks();
		deployHooks();
		deployMockModules();
	}

	function deployValidators() internal virtual {
		registerModule(
			address(K1_VALIDATOR = Deploy.k1Validator(SALT)),
			TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR)
		);
	}

	function deployExecutors() internal virtual {
		registerModule(address(PERMIT2_EXECUTOR = Deploy.permit2Executor(SALT)), TYPE_EXECUTOR.moduleTypes());

		registerModule(
			address(UNIVERSAL_EXECUTOR = Deploy.universalExecutor(META_FACTORY, SALT, WNATIVE.toAddress())),
			TYPE_EXECUTOR.moduleTypes()
		);
	}

	function deployFallbacks() internal virtual {
		registerModule(
			address(NATIVE_WRAPPER = Deploy.nativeWrapper(META_FACTORY, SALT, WNATIVE.toAddress())),
			TYPE_FALLBACK.moduleTypes()
		);

		if (isEthereum()) {
			registerModule(
				address(STETH_WRAPPER = Deploy.stETHWrapper(META_FACTORY, SALT, STETH.toAddress(), WSTETH.toAddress())),
				TYPE_FALLBACK.moduleTypes()
			);
		}
	}

	function deployHooks() internal virtual {}

	function deployMockModules() internal virtual {
		MOCK_VALIDATOR = MockValidator(
			deployModule(SALT, "MockValidator", "", TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR), true)
		);

		MOCK_EXECUTOR = MockExecutor(deployModule(SALT, "MockExecutor", "", TYPE_EXECUTOR.moduleTypes(), true));

		MOCK_FALLBACK = MockFallback(deployModule(SALT, "MockFallback", "", TYPE_FALLBACK.moduleTypes(), true));

		MOCK_HOOK = MockHook(deployModule(SALT, "MockHook", "", TYPE_HOOK.moduleTypes(), true));
	}

	function deployModule(
		bytes32 salt,
		string memory name,
		bytes memory args,
		ModuleType[] memory moduleTypeIds,
		bool useRegistry
	) internal returns (address module) {
		if (useRegistry) {
			bytes memory initCode = abi.encodePacked(Deploy.getCode(name), args);
			vm.label((module = REGISTRY.deployModule(salt, RESOLVER_UID, initCode, "", "")), name);
		} else {
			bytes memory bytecode = abi.encodePacked(Deploy.getCode(name));
			vm.label((module = META_FACTORY.deployModule(salt, bytecode, args)), name);
			REGISTRY.registerModule(RESOLVER_UID, module, "", "");
		}

		for (uint256 i; i < ATTESTERS.length; ++i) {
			ATTESTERS[i].attest(module, moduleTypeIds);
		}
	}

	function registerModule(address module, ModuleType[] memory moduleTypeIds) internal returns (address) {
		REGISTRY.registerModule(RESOLVER_UID, module, "", "");

		for (uint256 i; i < ATTESTERS.length; ++i) {
			ATTESTERS[i].attest(module, moduleTypeIds);
		}

		return module;
	}

	function createSigner(string memory name, bytes10 keyword) internal virtual returns (Signer memory signer) {
		return createSigner(name, keyword, INITIAL_BALANCE, 0, 0);
	}

	function createSigner(
		string memory name,
		bytes10 keyword,
		uint256 value,
		uint256 deposit,
		uint256 stake
	) internal virtual returns (Signer memory signer) {
		signer.privateKey = encodePrivateKey(name);
		(signer.publicKeyX, signer.publicKeyY) = vm.publicKeyP256(signer.privateKey);
		signer.eoa = payable(vm.addr(signer.privateKey));
		signer.keyword = keyword;

		vm.deal(signer.eoa, value + deposit + stake);
		vm.label(signer.eoa, name);

		if (deposit != 0) signer.addDeposit(deposit, signer.eoa);
		if (stake != 0) signer.addStake(stake, 1 weeks);
	}

	function createAttesters(
		string memory prefix,
		uint256 count,
		uint256 value
	) internal virtual returns (Attester[] memory attesters, address[] memory addresses) {
		uint256 privateKey = encodePrivateKey(prefix);

		attesters = new Attester[](count);
		addresses = new address[](count);

		for (uint256 i; i < count; ++i) {
			vm.deal(
				addresses[i] = attesters[i].eoa = payable(vm.addr(attesters[i].privateKey = privateKey + i)),
				value
			);
		}

		addresses.insertionSort();
		addresses.uniquifySorted();

		for (uint256 i; i < count; ++i) {
			vm.label(addresses[i], string.concat(prefix, " #", vm.toString(i)));

			for (uint256 j = i; j < count; ++j) {
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
