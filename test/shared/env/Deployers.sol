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
import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {STETHWrapperFallback} from "src/modules/fallbacks/STETHWrapperFallback.sol";
import {ECDSAValidator} from "src/modules/validators/ECDSAValidator.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";

import {Bootstrap} from "src/utils/Bootstrap.sol";
import {Vortex} from "src/Vortex.sol";

import {MockExecutor} from "test/shared/mocks/MockExecutor.sol";
import {MockFallback} from "test/shared/mocks/MockFallback.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {MockPreValidationHook1271} from "test/shared/mocks/MockPreValidationHook1271.sol";
import {MockPreValidationHook4337} from "test/shared/mocks/MockPreValidationHook4337.sol";
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
	using SolArray for *;

	struct Auxiliary {
		Vortex vortex;
		Bootstrap bootstrap;
		// Factories
		MetaFactory metaFactory;
		AccountFactory accountFactory;
		K1ValidatorFactory k1ValidatorFactory;
		RegistryFactory registryFactory;
		ModuleFactory moduleFactory;
		// Modules
		ECDSAValidator ecdsaValidator;
		K1Validator k1Validator;
		Permit2Executor permit2Executor;
		UniversalExecutor universalExecutor;
		NativeWrapperFallback nativeWrapper;
		STETHWrapperFallback stETHWrapper;
		// MockModules
		MockValidator mockValidator;
		MockExecutor mockExecutor;
		MockFallback mockFallback;
		MockHook mockHook;
		MockPreValidationHook1271 mockPreValidationHook1271;
		MockPreValidationHook4337 mockPreValidationHook4337;
	}

	bytes32 internal constant SALT = 0x0000000000000000000000000000000000000000000000000000000000007579;
	bytes32 internal constant RESOLVER_UID = 0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f;
	bytes32 internal constant SCHEMA_UID = 0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1;

	uint256 internal constant INITIAL_BALANCE = 1000 ether;
	uint256 internal constant INITIAL_VALUE = 100 ether;
	uint256 internal constant DEFAULT_VALUE = 10 ether;
	uint32 internal constant DEFAULT_DELAY = 1 weeks;

	Attester[] internal ATTESTERS;
	address[] internal ATTESTER_ADDRESSES;
	uint8 internal THRESHOLD = 1;

	Signer internal ADMIN;
	Signer internal BUNDLER;

	Signer internal ALICE;
	Signer internal COOPER;
	Signer internal MURPHY;

	Auxiliary internal aux;

	modifier impersonate(Signer memory signer, bool flag) {
		vm.startPrank(flag ? address(signer.account) : signer.eoa);
		_;
		vm.stopPrank();
	}

	function setUpAccounts() internal virtual {
		deployVortex(ALICE);
		deployVortex(COOPER);
		deployVortex(MURPHY);
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
		aux.metaFactory = new MetaFactory{salt: SALT}(ADMIN.eoa);
		aux.moduleFactory = new ModuleFactory{salt: SALT}(address(REGISTRY));
		aux.vortex = new Vortex{salt: SALT}();
		aux.bootstrap = new Bootstrap{salt: SALT}();
		deployModules();
		deployMockModules();
		deployFactories();
	}

	function deployVortex(Signer storage signer) internal virtual returns (Vortex) {
		if (signer.eoa == ALICE.eoa) {
			return deployVortex(signer, 0, address(aux.k1ValidatorFactory), address(aux.k1Validator), true);
		} else if (signer.eoa == COOPER.eoa) {
			return deployVortex(signer, 0, address(aux.registryFactory), address(aux.ecdsaValidator), true);
		} else if (signer.eoa == MURPHY.eoa) {
			return deployVortex(signer, 0, address(aux.accountFactory), address(aux.k1Validator), false);
		} else {
			revert("invalid signer");
		}
	}

	function deployVortex(
		Signer storage signer,
		uint16 id,
		address factory,
		address rootValidator,
		bool useRegistry
	) internal virtual returns (Vortex) {
		bytes32 salt = signer.encodeSalt(id);
		address payable account = aux.metaFactory.computeAddress(factory, salt);
		vm.assertTrue(account != address(0) && account.code.length == 0);

		bytes memory initCode = getAccountInitCode(signer.eoa, salt, factory, rootValidator, useRegistry, true);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = signer.prepareUserOp(account, initCode, rootValidator);

		ENTRYPOINT.depositTo{value: INITIAL_VALUE}(account);
		ENTRYPOINT.handleOps(userOps, signer.eoa);

		vm.assertEq((signer.account = Vortex(account)).rootValidator(), rootValidator);
		vm.assertEq(K1Validator(rootValidator).getAccountOwner(account), signer.eoa);
		vm.label(account, string.concat(vm.getLabel(signer.eoa), " Vortex"));

		return signer.account;
	}

	function getAccountInitCode(
		address owner,
		bytes32 salt,
		address factory,
		address validator,
		bool useRegistry,
		bool useMetaFactory
	) internal view virtual returns (bytes memory initCode) {
		vm.assertTrue(aux.metaFactory.isAuthorized(factory));

		address registry;
		address[] memory attesters;
		uint8 threshold;

		if (useRegistry) (registry, attesters, threshold) = (address(REGISTRY), ATTESTER_ADDRESSES, THRESHOLD);

		BootstrapConfig memory rootValidator = validator == address(aux.k1Validator)
			? validator.build(abi.encodePacked(owner, BUNDLER.eoa, PERMIT2), "")
			: validator.build(abi.encodePacked(owner), "");

		bytes memory params;

		if (factory == address(aux.accountFactory)) {
			bytes memory initializer = aux.bootstrap.getInitializeWithRootValidatorCalldata(
				rootValidator,
				registry,
				attesters,
				threshold
			);

			params = abi.encodeCall(Vortex.initializeAccount, (initializer));
		} else if (factory == address(aux.registryFactory)) {
			BootstrapConfig[] memory validators = address(aux.mockValidator)
				.build(abi.encodePacked(owner), "")
				.arrayify();

			BootstrapConfig[] memory executors = address(aux.mockExecutor).build("", "").arrayify();

			bytes4[] memory selectors = MockFallback.fallbackSingle.selector.bytes4s(
				MockFallback.fallbackDelegate.selector,
				MockFallback.fallbackStatic.selector,
				MockFallback.fallbackSuccess.selector
			);

			CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
				CALLTYPE_DELEGATE,
				CALLTYPE_STATIC,
				CALLTYPE_STATIC
			);

			BootstrapConfig[] memory fallbacks = address(aux.mockFallback)
				.build(abi.encode(encodeFallbackSelectors(selectors, callTypes), ""), "")
				.arrayify();

			BootstrapConfig[] memory hooks = address(aux.mockHook).build(vm.randomBytes(32), "").arrayify();

			BootstrapConfig memory preValidationHook1271 = address(aux.mockPreValidationHook1271).build(
				abi.encodePacked(bytes32(0x1271127112711271127112711271127112711271127112711271127112711271)),
				""
			);

			BootstrapConfig memory preValidationHook4337 = address(aux.mockPreValidationHook4337).build(
				abi.encodePacked(bytes32(0x4337433743374337433743374337433743374337433743374337433743374337)),
				""
			);

			params = abi.encode(
				rootValidator,
				validators,
				executors,
				fallbacks,
				hooks,
				preValidationHook1271,
				preValidationHook4337
			);
		} else if (factory == address(aux.k1ValidatorFactory)) {
			params = abi.encode(owner, BUNDLER.eoa.addresses(address(PERMIT2)), attesters, threshold);
		} else {
			revert("invalid factory");
		}

		initCode = abi.encodePacked(factory, abi.encodeCall(AccountFactory.createAccount, (salt, params)));

		if (useMetaFactory) {
			initCode = abi.encodePacked(aux.metaFactory, abi.encodeCall(MetaFactory.createAccount, (initCode)));
		}
	}

	function deployFactories() internal virtual {
		aux.accountFactory = new AccountFactory{salt: SALT}(address(aux.vortex), ADMIN.eoa);

		aux.k1ValidatorFactory = new K1ValidatorFactory{salt: SALT}(
			address(aux.vortex),
			address(aux.k1Validator),
			address(aux.bootstrap),
			address(REGISTRY),
			ADMIN.eoa
		);

		aux.registryFactory = new RegistryFactory{salt: SALT}(
			address(aux.vortex),
			address(aux.bootstrap),
			address(REGISTRY),
			ADMIN.eoa
		);
	}

	function setUpFactories() internal virtual impersonate(ADMIN, false) {
		aux.metaFactory.authorize(address(aux.accountFactory));
		aux.metaFactory.authorize(address(aux.k1ValidatorFactory));
		aux.metaFactory.authorize(address(aux.registryFactory));

		aux.metaFactory.stake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_DELAY);
		aux.accountFactory.stake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_DELAY);
		aux.k1ValidatorFactory.stake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_DELAY);
		aux.registryFactory.stake{value: DEFAULT_VALUE}(address(ENTRYPOINT), DEFAULT_DELAY);

		aux.registryFactory.configure(ATTESTER_ADDRESSES, THRESHOLD);
	}

	function deployModules() internal virtual {
		aux.k1Validator = K1Validator(
			deployModule(TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR), type(K1Validator).creationCode, "")
		);

		aux.ecdsaValidator = ECDSAValidator(
			deployModule(TYPE_VALIDATOR.moduleTypes(TYPE_HOOK), type(ECDSAValidator).creationCode, "")
		);

		aux.permit2Executor = Permit2Executor(
			deployModule(TYPE_EXECUTOR.moduleTypes(), type(Permit2Executor).creationCode, "")
		);

		aux.universalExecutor = UniversalExecutor(
			deployModule(TYPE_EXECUTOR.moduleTypes(), type(UniversalExecutor).creationCode, abi.encode(WNATIVE))
		);

		aux.nativeWrapper = NativeWrapperFallback(
			deployModule(TYPE_FALLBACK.moduleTypes(), type(NativeWrapperFallback).creationCode, abi.encode(WNATIVE))
		);

		if (isEthereum()) {
			aux.stETHWrapper = STETHWrapperFallback(
				deployModule(
					TYPE_FALLBACK.moduleTypes(),
					type(STETHWrapperFallback).creationCode,
					abi.encode(STETH, WSTETH)
				)
			);
		}
	}

	function deployMockModules() internal virtual {
		aux.mockValidator = MockValidator(
			deployModule(TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR), type(MockValidator).creationCode, "")
		);

		aux.mockExecutor = MockExecutor(deployModule(TYPE_EXECUTOR.moduleTypes(), type(MockExecutor).creationCode, ""));

		aux.mockFallback = MockFallback(deployModule(TYPE_FALLBACK.moduleTypes(), type(MockFallback).creationCode, ""));

		aux.mockHook = MockHook(deployModule(TYPE_HOOK.moduleTypes(), type(MockHook).creationCode, ""));

		aux.mockPreValidationHook1271 = MockPreValidationHook1271(
			deployModule(
				TYPE_PREVALIDATION_HOOK_ERC1271.moduleTypes(),
				type(MockPreValidationHook1271).creationCode,
				""
			)
		);

		aux.mockPreValidationHook4337 = MockPreValidationHook4337(
			deployModule(
				TYPE_PREVALIDATION_HOOK_ERC4337.moduleTypes(),
				type(MockPreValidationHook4337).creationCode,
				""
			)
		);
	}

	function deployModule(
		ModuleType[] memory moduleTypeIds,
		bytes memory bytecode,
		bytes memory args
	) internal virtual returns (address module) {
		ATTESTERS[0].attest((module = aux.moduleFactory.deployModule(SALT, bytecode, args)), moduleTypeIds);
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
		if (stake != 0) signer.addStake(stake, DEFAULT_DELAY);
	}

	function createAttesters(
		uint256 length
	) internal virtual returns (Attester[] memory attesters, address[] memory addresses) {
		string memory prefix = "Attester";
		uint256 key = encodePrivateKey(prefix);

		attesters = new Attester[](length);
		addresses = new address[](length);

		for (uint256 i; i < length; ++i) {
			vm.deal(addresses[i] = attesters[i].eoa = payable(vm.addr(attesters[i].key = key + i)), INITIAL_BALANCE);
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

	function encodeModuleParams(
		bytes memory data,
		bytes memory hookData
	) internal pure virtual returns (bytes memory params) {
		params = abi.encodePacked(bytes4(uint32(data.length)), data, bytes4(uint32(hookData.length)), hookData);
	}

	function encodeUninstallModuleParams(
		bytes memory data,
		bytes memory hookData
	) internal pure virtual returns (bytes memory params) {
		params = abi.encodePacked(bytes4(uint32(data.length)), data, bytes4(uint32(hookData.length)), hookData);
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
