// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {AccountIdLib} from "src/libraries/AccountIdLib.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {CallType, ModuleType} from "src/types/Types.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {Signer} from "test/shared/structs/Signer.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract ModuleManagerTest is BaseTest {
	using AccountIdLib for string;
	using SolArray for *;

	function setUp() public virtual override {
		super.setUp();
		deployVortex(MURPHY, 0, INITIAL_VALUE, address(ACCOUNT_FACTORY), false);
	}

	function test_enableModule() public virtual {
		address enableValidator = address(K1_VALIDATOR);
		address opValidator = address(MOCK_VALIDATOR);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory initData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		PackedUserOperation[] memory userOps;

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectEmit(true, true, true, true);
		emit ModuleInstalled(TYPE_VALIDATOR, opValidator);

		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));
		assertEq(MURPHY.account.rootValidator(), opValidator);

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectEmit(true, true, true, true);
		emit ModuleInstalled(TYPE_VALIDATOR, opValidator);

		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));
		assertEq(MURPHY.account.rootValidator(), opValidator);
	}

	function test_enableModule_revertsWithInvalidSignature() public virtual {
		address enableValidator = address(K1_VALIDATOR);
		address opValidator = address(MOCK_VALIDATOR);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory initData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(EnableNotApproved.selector)
		);

		PackedUserOperation[] memory userOps;

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, false, false);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, false, true);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);
	}

	function test_enableModule_revertsIfModuleAlreadyInstalled() public virtual {
		address enableValidator = address(K1_VALIDATOR);
		address opValidator = address(MOCK_VALIDATOR);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory initData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		MURPHY.install(TYPE_VALIDATOR, opValidator, initData);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(ModuleAlreadyInstalled.selector, opValidator)
		);

		PackedUserOperation[] memory userOps;

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);
	}

	function test_enableModule_revertsWithInvalidValidator() public virtual {
		address opValidator = address(MOCK_VALIDATOR);
		address invalidValidator = opValidator;

		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory initData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(ModuleNotInstalled.selector, invalidValidator)
		);

		PackedUserOperation[] memory userOps;

		revertToState();

		userOps = prepareEnableModule(invalidValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		revertToState();

		userOps = prepareEnableModule(invalidValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);
	}

	function test_enableModule_revertsWithInvalidModuleTypeId() public virtual {
		address enableValidator = address(K1_VALIDATOR);
		address opValidator = address(MOCK_VALIDATOR);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		ModuleType[] memory moduleTypeIds = TYPE_EXECUTOR.moduleTypes();

		bytes memory initData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(InvalidModuleType.selector)
		);

		PackedUserOperation[] memory userOps;

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_EXECUTOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);

		revertToState();

		userOps = prepareEnableModule(enableValidator, TYPE_EXECUTOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		ENTRYPOINT.handleOps(userOps, MURPHY.eoa);
	}

	function test_configureRootValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
		assertEq(MURPHY.account.rootValidator(), address(K1_VALIDATOR));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory installData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");

		Execution memory execution = Execution({
			target: address(MURPHY.account),
			value: 0,
			callData: abi.encodeCall(Vortex.configureRootValidator, (address(MOCK_VALIDATOR), installData))
		});

		vm.expectEmit(true, true, true, true);
		emit RootValidatorConfigured(address(MOCK_VALIDATOR));

		MURPHY.execute(EXECTYPE_DEFAULT, execution);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
		assertEq(MURPHY.account.rootValidator(), address(MOCK_VALIDATOR));
	}

	function test_installValidatorThenSetRootValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
		assertEq(MURPHY.account.rootValidator(), address(K1_VALIDATOR));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory installData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");

		Execution[] memory executions = new Execution[](2);
		executions[0] = Execution(
			address(MURPHY.account),
			0,
			abi.encodeCall(Vortex.installModule, (TYPE_VALIDATOR, address(MOCK_VALIDATOR), installData))
		);
		executions[1] = Execution(
			address(MURPHY.account),
			0,
			abi.encodeCall(Vortex.configureRootValidator, (address(MOCK_VALIDATOR), ""))
		);

		vm.expectEmit(true, true, true, true);
		emit RootValidatorConfigured(address(MOCK_VALIDATOR));

		MURPHY.execute(EXECTYPE_DEFAULT, executions);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
		assertEq(MURPHY.account.rootValidator(), address(MOCK_VALIDATOR));
	}

	function test_configureRegistry() public virtual {
		assertEq(MURPHY.account.registry(), address(0));

		vm.expectEmit(true, true, true, true);
		emit RegistryConfigured(address(REGISTRY));

		Execution memory execution = Execution({
			target: address(MURPHY.account),
			value: 0,
			callData: abi.encodeCall(Vortex.configureRegistry, (address(REGISTRY), ATTESTER_ADDRESSES, THRESHOLD))
		});

		MURPHY.execute(EXECTYPE_DEFAULT, execution);
		assertEq(MURPHY.account.registry(), address(REGISTRY));

		execution = Execution({
			target: address(MURPHY.account),
			value: 0,
			callData: abi.encodeCall(Vortex.configureRegistry, (address(0), new address[](0), 0))
		});

		vm.expectEmit(true, true, true, true);
		emit RegistryConfigured(address(0));

		MURPHY.execute(EXECTYPE_DEFAULT, execution);
		assertEq(MURPHY.account.registry(), address(0));
	}

	function test_installValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));

		ModuleType[] memory moduleTypeIds = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);

		bytes memory installData = encodeInstallModuleData(moduleTypeIds, abi.encodePacked(MURPHY.eoa), "");

		MURPHY.install(TYPE_VALIDATOR, address(MOCK_VALIDATOR), installData);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));

		MURPHY.uninstall(TYPE_VALIDATOR, address(MOCK_VALIDATOR), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
	}

	function test_installExecutor() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(MOCK_EXECUTOR), ""));

		bytes memory installData = encodeInstallModuleData(TYPE_EXECUTOR.moduleTypes(), "", "");

		MURPHY.install(TYPE_EXECUTOR, address(MOCK_EXECUTOR), installData);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(MOCK_EXECUTOR), ""));

		MURPHY.uninstall(TYPE_EXECUTOR, address(MOCK_EXECUTOR), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(MOCK_EXECUTOR), ""));
	}

	function test_installFallback() public virtual {
		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

		for (uint256 i; i < configurations.length; ++i) {
			bytes memory additionalContext = abi.encodePacked(bytes5(configurations[i]));
			assertFalse(MURPHY.account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_FALLBACK), additionalContext));
		}

		bytes memory installData = encodeInstallModuleData(
			TYPE_FALLBACK.moduleTypes(),
			abi.encode(configurations, ""),
			abi.encodePacked(MOCK_HOOK, "")
		);

		MURPHY.install(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);

		for (uint256 i; i < configurations.length; ++i) {
			bytes memory additionalContext = abi.encodePacked(bytes5(configurations[i]));
			assertTrue(MURPHY.account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_FALLBACK), additionalContext));
		}

		bytes memory uninstallData = encodeUninstallModuleData(abi.encode(selectors, ""), "");

		MURPHY.uninstall(TYPE_FALLBACK, address(MOCK_FALLBACK), uninstallData);

		for (uint256 i; i < selectors.length; ++i) {
			bytes memory additionalContext = abi.encodePacked(selectors[i]);
			assertFalse(MURPHY.account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_FALLBACK), additionalContext));
		}
	}

	function test_installHook() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));

		bytes memory installData = encodeInstallModuleData(TYPE_HOOK.moduleTypes(), vm.randomBytes(64), "");

		MURPHY.install(TYPE_HOOK, address(MOCK_HOOK), installData);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));

		MURPHY.uninstall(TYPE_HOOK, address(MOCK_HOOK), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));
	}

	function test_installMultipleHooks() public virtual {
		address[] memory hooks = new address[](4);
		hooks[0] = address(new MockHook());
		hooks[1] = address(new MockHook());
		hooks[2] = address(new MockHook());
		hooks[3] = address(new MockHook());

		ModuleType[] memory hookTypes = TYPE_HOOK.moduleTypes();

		for (uint256 i; i < hooks.length; ++i) {
			bytes memory installData = encodeInstallModuleData(hookTypes, vm.randomBytes(32 * (i + 1)), "");

			MURPHY.install(TYPE_HOOK, hooks[i], installData);
			assertTrue(MURPHY.account.isModuleInstalled(TYPE_HOOK, hooks[i], ""));
		}

		address target = WETH.toAddress();
		uint256 value = 5 ether;

		Execution memory execution = Execution({
			target: target,
			value: value,
			callData: abi.encodeWithSignature("deposit()")
		});

		assertEq(WETH.balanceOf(address(MURPHY.account)), 0);
		deal(address(MURPHY.account), address(MURPHY.account).balance + value);

		MURPHY.execute(EXECTYPE_DEFAULT, execution);
		assertEq(WETH.balanceOf(address(MURPHY.account)), value);
	}

	function test_installModule_revertsIfAlreadyInstalled() public virtual asEntryPoint {
		ModuleType[] memory moduleTypeIds = TYPE_FALLBACK.moduleTypes();

		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

		bytes memory installData = encodeInstallModuleData(
			moduleTypeIds,
			abi.encode(configurations, ""),
			abi.encodePacked(MOCK_HOOK, "")
		);

		MURPHY.account.installModule(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);

		vm.expectRevert(abi.encodeWithSelector(ModuleAlreadyInstalled.selector, MOCK_FALLBACK));
		MURPHY.account.installModule(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);
	}

	function test_uninstallModule_revertsIfNotInstalled() public virtual asEntryPoint {
		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		bytes memory uninstallData = encodeUninstallModuleData(abi.encode(selectors, ""), "");

		vm.expectRevert(abi.encodeWithSelector(ModuleNotInstalled.selector, MOCK_FALLBACK));
		MURPHY.account.uninstallModule(TYPE_FALLBACK, address(MOCK_FALLBACK), uninstallData);
	}

	function test_installModule_revertsWithInvalidModuleTypeId() public virtual asEntryPoint {
		vm.expectRevert(InvalidModuleType.selector);

		bytes memory data = abi.encodePacked(MURPHY.eoa);

		MURPHY.account.installModule(
			TYPE_FALLBACK,
			address(MOCK_VALIDATOR),
			encodeInstallModuleData(TYPE_FALLBACK.moduleTypes(), data, "")
		);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_VALIDATOR), ""));

		ModuleType invalidType = ModuleType.wrap(0x00);

		vm.expectRevert(abi.encodeWithSelector(UnsupportedModuleType.selector, invalidType));

		MURPHY.account.installModule(
			invalidType,
			address(MOCK_VALIDATOR),
			encodeInstallModuleData(invalidType.moduleTypes(), data, "")
		);

		invalidType = ModuleType.wrap(0x08);

		vm.expectRevert(abi.encodeWithSelector(UnsupportedModuleType.selector, invalidType));

		MURPHY.account.installModule(
			invalidType,
			address(MOCK_VALIDATOR),
			encodeInstallModuleData(invalidType.moduleTypes(), data, "")
		);
	}

	function test_installFallback_revertsWithInvalidFlag() public virtual asEntryPoint {
		ModuleType[] memory moduleTypeIds = TYPE_FALLBACK.moduleTypes();

		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

		vm.expectRevert(InvalidFlag.selector);
		MURPHY.account.installModule(
			TYPE_FALLBACK,
			address(MOCK_FALLBACK),
			encodeInstallModuleData(
				moduleTypeIds,
				abi.encode(configurations, abi.encodePacked(bytes1(0x01))),
				abi.encodePacked(MOCK_HOOK, "")
			)
		);

		vm.expectRevert(InvalidFlag.selector);
		MURPHY.account.installModule(
			TYPE_FALLBACK,
			address(MOCK_FALLBACK),
			encodeInstallModuleData(
				moduleTypeIds,
				abi.encode(configurations, abi.encodePacked(bytes1(0x02))),
				abi.encodePacked(MOCK_HOOK, "")
			)
		);
	}

	function test_installFallback_revertsWithInvalidCallTypes() public virtual asEntryPoint {
		ModuleType[] memory moduleTypeIds = TYPE_FALLBACK.moduleTypes();

		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		// call type of CALLTYPE_BATCH is not supported for fallback handlers
		CallType[] memory callTypes = CALLTYPE_BATCH.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes memory installData = encodeInstallModuleData(
			moduleTypeIds,
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			abi.encodePacked(MOCK_HOOK, "")
		);

		vm.expectRevert(abi.encodeWithSelector(UnsupportedCallType.selector, CALLTYPE_BATCH));
		MURPHY.account.installModule(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);
	}

	function test_installFallback_revertsWithForbiddenSelectors() public virtual asEntryPoint {
		ModuleType[] memory moduleTypeIds = TYPE_FALLBACK.moduleTypes();

		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes4[] memory forbiddenSelectors = MURPHY.account.forbiddenSelectors();

		for (uint256 i; i < forbiddenSelectors.length; ++i) {
			bytes4 selector = selectors[0] = forbiddenSelectors[i];

			bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

			bytes memory installData = encodeInstallModuleData(
				moduleTypeIds,
				abi.encode(configurations, ""),
				abi.encodePacked(MOCK_HOOK, "")
			);

			vm.expectRevert(abi.encodeWithSelector(ForbiddenSelector.selector, selector));
			MURPHY.account.installModule(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);
		}
	}

	function test_uninstallFallback_revertsWithUnknownSelectors() public virtual asEntryPoint {
		ModuleType[] memory moduleTypeIds = TYPE_FALLBACK.moduleTypes();

		bytes4[] memory selectors = MOCK_FALLBACK.fallbackSingle.selector.bytes4s(
			MOCK_FALLBACK.fallbackDelegate.selector,
			MOCK_FALLBACK.fallbackStatic.selector,
			MOCK_FALLBACK.fallbackSuccess.selector,
			MOCK_FALLBACK.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes32[] memory configurations = encodeFallbackSelectors(selectors, callTypes);

		bytes memory installData = encodeInstallModuleData(
			moduleTypeIds,
			abi.encode(configurations, ""),
			abi.encodePacked(MOCK_HOOK, "")
		);

		MURPHY.account.installModule(TYPE_FALLBACK, address(MOCK_FALLBACK), installData);

		for (uint256 i; i < configurations.length; ++i) {
			bytes memory additionalContext = abi.encodePacked(bytes5(configurations[i]));
			assertTrue(MURPHY.account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_FALLBACK), additionalContext));
		}

		bytes memory uninstallData = encodeUninstallModuleData(abi.encode(bytes4(0xdeadbeef).bytes4s(), ""), "");

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, bytes4(0xdeadbeef)));
		MURPHY.account.uninstallModule(TYPE_FALLBACK, address(MOCK_FALLBACK), uninstallData);
	}

	function prepareEnableModule(
		address enableValidator,
		ModuleType moduleTypeId,
		address module,
		bytes memory initData,
		bytes memory callData,
		bool useValidSignature,
		bool useERC7739
	) internal view virtual returns (PackedUserOperation[] memory userOps) {
		userOps = new PackedUserOperation[](1);
		bytes32 userOpHash;

		(userOps[0], userOpHash) = MURPHY.prepareUserOp(callData, module, VALIDATION_MODE_ENABLE);

		bytes32 structHash = keccak256(
			abi.encode(ENABLE_MODULE_TYPEHASH, moduleTypeId, module, keccak256(initData), userOpHash)
		);

		bytes32 enableModuleHash;
		bytes memory enableSignature;

		if (useERC7739) {
			(string memory name, string memory version) = MURPHY.account.accountId().parse();

			bytes memory domainFields = abi.encode(
				keccak256(bytes(name)),
				keccak256(bytes(version)),
				block.chainid,
				MURPHY.account,
				bytes32(0)
			);

			enableModuleHash = MURPHY.account.hashTypedData(
				keccak256(
					abi.encodePacked(
						abi.encode(
							keccak256(
								abi.encodePacked(
									string.concat(
										"TypedDataSign(EnableModule contents,string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)",
										ENABLE_MODULE_NOTATION
									)
								)
							),
							structHash
						),
						domainFields
					)
				)
			);

			bytes memory contentsType = bytes(ENABLE_MODULE_NOTATION);
			uint16 contentsLength = uint16(contentsType.length);

			enableSignature = abi.encodePacked(
				enableValidator,
				(useValidSignature ? MURPHY : COOPER).sign(enableModuleHash),
				MURPHY.account.DOMAIN_SEPARATOR(),
				structHash,
				contentsType,
				contentsLength
			);
		} else {
			enableModuleHash = MURPHY.account.hashTypedData(structHash);

			enableSignature = abi.encodePacked(
				enableValidator,
				(useValidSignature ? MURPHY : COOPER).sign(enableModuleHash)
			);
		}

		bytes memory enableModuleData = abi.encodePacked(
			bytes1(uint8(ModuleType.unwrap(moduleTypeId))),
			module,
			bytes4(uint32(initData.length)),
			initData,
			bytes4(uint32(enableSignature.length)),
			enableSignature
		);

		userOps[0].signature = abi.encodePacked(enableModuleData, userOps[0].signature);
	}
}
