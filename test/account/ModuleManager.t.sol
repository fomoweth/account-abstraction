// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IModule} from "src/interfaces/IERC7579Modules.sol";
import {CallType, ExecType, ModuleType} from "src/types/DataTypes.sol";
import {Vortex} from "src/Vortex.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {MockHook} from "test/shared/mocks/MockHook.sol";
import {ExecutionUtils, Execution} from "test/shared/utils/ExecutionUtils.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";

contract ModuleManagerTest is BaseTest {
	using ExecutionUtils for ExecType;
	using SolArray for *;

	error ExceededMaxGlobalHooksLimit();

	function setUp() public virtual override {
		super.setUp();
		deployVortex(MURPHY);
	}

	function test_enableModule() public virtual {
		revertToState();

		address enableValidator = address(aux.k1Validator);
		address opValidator = address(aux.mockValidator);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory initData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectEmit(true, false, false, true);
		emit ModuleInstalled(TYPE_VALIDATOR, opValidator);

		BUNDLER.handleOps(userOps);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));
		assertEq(MURPHY.account.rootValidator(), opValidator);

		revertToState();

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectEmit(true, false, false, true);
		emit ModuleInstalled(TYPE_VALIDATOR, opValidator);

		BUNDLER.handleOps(userOps);

		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));
		assertEq(MURPHY.account.rootValidator(), opValidator);
	}

	function test_enableModule_revertsWithInvalidSignature() public virtual {
		address enableValidator = address(aux.k1Validator);
		address opValidator = address(aux.mockValidator);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory initData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(EnableNotApproved.selector)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, false, true);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, false, false);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);
	}

	function test_enableModule_revertsIfModuleAlreadyInstalled() public virtual {
		address enableValidator = address(aux.k1Validator);
		address opValidator = address(aux.mockValidator);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory initData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		MURPHY.install(TYPE_VALIDATOR, opValidator, initData);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(ModuleAlreadyInstalled.selector, TYPE_VALIDATOR, opValidator)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);

		userOps[0] = prepareEnable(enableValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);
	}

	function test_enableModule_revertsWithInvalidValidator() public virtual {
		address opValidator = address(aux.mockValidator);
		address invalidValidator = opValidator;

		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory initData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(ModuleNotInstalled.selector, TYPE_VALIDATOR, invalidValidator)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		userOps[0] = prepareEnable(invalidValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);

		userOps[0] = prepareEnable(invalidValidator, TYPE_VALIDATOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);
	}

	function test_enableModule_revertsWithInvalidModuleTypeId() public virtual {
		address enableValidator = address(aux.k1Validator);
		address opValidator = address(aux.mockValidator);

		assertEq(MURPHY.account.rootValidator(), enableValidator);
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, opValidator, ""));

		bytes memory initData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(Vortex.configureRootValidator, (opValidator, ""));

		bytes memory revertReason = abi.encodeWithSelector(
			IEntryPoint.FailedOpWithRevert.selector,
			0,
			"AA23 reverted",
			abi.encodeWithSelector(InvalidModuleType.selector)
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

		userOps[0] = prepareEnable(enableValidator, TYPE_EXECUTOR, opValidator, initData, callData, true, true);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);

		userOps[0] = prepareEnable(enableValidator, TYPE_EXECUTOR, opValidator, initData, callData, true, false);

		vm.expectRevert(revertReason);
		BUNDLER.handleOps(userOps);
	}

	function test_configureRootValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));
		assertEq(MURPHY.account.rootValidator(), address(aux.k1Validator));

		bytes memory installData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");
		bytes memory callData = abi.encodeCall(
			Vortex.configureRootValidator,
			(address(aux.mockValidator), installData)
		);
		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		vm.expectEmit(true, true, true, true);
		emit RootValidatorConfigured(address(aux.mockValidator));

		BUNDLER.handleOps(userOps);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));
		assertEq(MURPHY.account.rootValidator(), address(aux.mockValidator));
	}

	function test_installValidatorThenSetRootValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));
		assertEq(MURPHY.account.rootValidator(), address(aux.k1Validator));

		bytes memory installData = encodeModuleParams(abi.encodePacked(MURPHY.eoa), "");

		Execution[] memory executions = new Execution[](2);
		executions[0] = Execution(
			address(MURPHY.account),
			0,
			abi.encodeCall(Vortex.installModule, (TYPE_VALIDATOR, address(aux.mockValidator), installData))
		);
		executions[1] = Execution(
			address(MURPHY.account),
			0,
			abi.encodeCall(Vortex.configureRootValidator, (address(aux.mockValidator), ""))
		);

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(executions);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		vm.expectEmit(true, true, true, true);
		emit RootValidatorConfigured(address(aux.mockValidator));

		BUNDLER.handleOps(userOps);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));
		assertEq(MURPHY.account.rootValidator(), address(aux.mockValidator));
	}

	function test_configureRegistry() public virtual {
		assertEq(MURPHY.account.registry(), address(0));

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		bytes memory callData;
		bytes memory executionCalldata;

		vm.expectEmit(true, true, true, true);
		emit RegistryConfigured(address(REGISTRY));

		callData = abi.encodeCall(Vortex.configureRegistry, (address(REGISTRY), ATTESTER_ADDRESSES, THRESHOLD));
		executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(MURPHY.account.registry(), address(REGISTRY));

		vm.expectEmit(true, true, true, true);
		emit RegistryConfigured(address(0));

		callData = abi.encodeCall(Vortex.configureRegistry, (address(0), new address[](0), 0));
		executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(address(MURPHY.account), 0, callData);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		BUNDLER.handleOps(userOps);
		assertEq(MURPHY.account.registry(), address(0));
	}

	function test_installValidator() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));

		MURPHY.install(
			TYPE_VALIDATOR,
			address(aux.mockValidator),
			encodeModuleParams(abi.encodePacked(MURPHY.eoa), "")
		);
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));

		MURPHY.uninstall(TYPE_VALIDATOR, address(aux.mockValidator), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_VALIDATOR, address(aux.mockValidator), ""));
	}

	function test_installExecutor() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.mockExecutor), ""));

		MURPHY.install(TYPE_EXECUTOR, address(aux.mockExecutor), encodeModuleParams("", ""));
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.mockExecutor), ""));

		MURPHY.uninstall(TYPE_EXECUTOR, address(aux.mockExecutor), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.mockExecutor), ""));
	}

	function test_installFallback() public virtual {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		for (uint256 i; i < selectors.length; ++i) {
			assertFalse(
				MURPHY.account.isModuleInstalled(
					TYPE_FALLBACK,
					address(aux.mockFallback),
					abi.encodePacked(selectors[i])
				)
			);
		}

		MURPHY.install(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeModuleParams(
				abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
				abi.encodePacked(aux.mockHook, "")
			)
		);

		for (uint256 i; i < selectors.length; ++i) {
			assertTrue(
				MURPHY.account.isModuleInstalled(
					TYPE_FALLBACK,
					address(aux.mockFallback),
					abi.encodePacked(selectors[i])
				)
			);
		}

		MURPHY.uninstall(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeUninstallModuleParams(abi.encode(selectors, ""), "")
		);

		for (uint256 i; i < selectors.length; ++i) {
			assertFalse(
				MURPHY.account.isModuleInstalled(
					TYPE_FALLBACK,
					address(aux.mockFallback),
					abi.encodePacked(selectors[i])
				)
			);
		}
	}

	function test_installHook() public virtual {
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(aux.mockHook), ""));

		MURPHY.install(TYPE_HOOK, address(aux.mockHook), encodeModuleParams(vm.randomBytes(64), ""));
		assertTrue(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(aux.mockHook), ""));

		MURPHY.uninstall(TYPE_HOOK, address(aux.mockHook), "");
		assertFalse(MURPHY.account.isModuleInstalled(TYPE_HOOK, address(aux.mockHook), ""));
	}

	function test_installHooks(uint8 seed) public virtual {
		uint256 length = bound(seed, 1, 32);
		address[] memory hooks = new address[](length);

		for (uint256 i; i < length; ++i) {
			MURPHY.install(
				TYPE_HOOK,
				(hooks[i] = address(new MockHook())),
				encodeModuleParams(vm.randomBytes(32 * (i + 1)), "")
			);
			assertTrue(MURPHY.account.isModuleInstalled(TYPE_HOOK, hooks[i], ""));
		}

		bytes memory executionCalldata = EXECTYPE_DEFAULT.encodeExecutionCalldata(
			WNATIVE.toAddress(),
			DEFAULT_VALUE,
			abi.encodeWithSignature("deposit()")
		);

		PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
		(userOps[0], ) = MURPHY.prepareUserOp(executionCalldata);

		assertEq(WNATIVE.balanceOf(address(MURPHY.account)), 0);
		deal(address(MURPHY.account), address(MURPHY.account).balance + DEFAULT_VALUE);

		BUNDLER.handleOps(userOps);
		assertEq(WNATIVE.balanceOf(address(MURPHY.account)), DEFAULT_VALUE);
	}

	function test_installModule_revertsIfAlreadyInstalled() public virtual asEntryPoint {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes memory installData = encodeModuleParams(
			abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
			abi.encodePacked(aux.mockHook, "")
		);

		MURPHY.account.installModule(TYPE_FALLBACK, address(aux.mockFallback), installData);

		vm.expectRevert(abi.encodeWithSelector(ModuleAlreadyInstalled.selector, TYPE_FALLBACK, aux.mockFallback));
		MURPHY.account.installModule(TYPE_FALLBACK, address(aux.mockFallback), installData);
	}

	function test_uninstallModule_revertsIfNotInstalled() public virtual asEntryPoint {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		vm.expectRevert(abi.encodeWithSelector(ModuleNotInstalled.selector, TYPE_FALLBACK, aux.mockFallback));
		MURPHY.account.uninstallModule(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeUninstallModuleParams(abi.encode(selectors, ""), "")
		);
	}

	function test_installModule_revertsWithInvalidModuleTypeId() public virtual asEntryPoint {
		bytes memory data = abi.encodePacked(MURPHY.eoa);

		vm.expectRevert(InvalidModuleType.selector);
		MURPHY.account.installModule(TYPE_EXECUTOR, address(aux.mockValidator), encodeModuleParams(data, ""));

		assertFalse(MURPHY.account.isModuleInstalled(TYPE_EXECUTOR, address(aux.mockValidator), ""));

		ModuleType[] memory moduleTypes = TYPE_MULTI.moduleTypes(
			TYPE_POLICY,
			TYPE_SIGNER,
			ModuleType.wrap(0x0a),
			ModuleType.wrap(0x0b)
		);

		for (uint256 i; i < moduleTypes.length; ++i) {
			vm.expectRevert(abi.encodeWithSelector(UnsupportedModuleType.selector, moduleTypes[i]));
			MURPHY.account.installModule(moduleTypes[i], address(aux.mockValidator), encodeModuleParams(data, ""));
		}
	}

	function test_installFallback_revertsWithInvalidCallTypes() public virtual asEntryPoint {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_BATCH.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		vm.expectRevert(abi.encodeWithSelector(UnsupportedCallType.selector, CALLTYPE_BATCH));
		MURPHY.account.installModule(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeModuleParams(
				abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
				abi.encodePacked(aux.mockHook, "")
			)
		);
	}

	function test_installFallback_revertsWithForbiddenSelectors() public virtual asEntryPoint {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		bytes4[] memory forbiddenSelectors = IModule.onInstall.selector.bytes4s(IModule.onUninstall.selector);

		for (uint256 i; i < forbiddenSelectors.length; ++i) {
			bytes4 selector = selectors[0] = forbiddenSelectors[i];

			vm.expectRevert(abi.encodeWithSelector(ForbiddenSelector.selector, selector));
			MURPHY.account.installModule(
				TYPE_FALLBACK,
				address(aux.mockFallback),
				encodeModuleParams(
					abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
					abi.encodePacked(aux.mockHook, "")
				)
			);
		}
	}

	function test_uninstallFallback_revertsWithUnknownSelectors() internal virtual asEntryPoint {
		bytes4[] memory selectors = aux.mockFallback.fallbackSingle.selector.bytes4s(
			aux.mockFallback.fallbackDelegate.selector,
			aux.mockFallback.fallbackStatic.selector,
			aux.mockFallback.fallbackSuccess.selector,
			aux.mockFallback.fallbackRevert.selector
		);

		CallType[] memory callTypes = CALLTYPE_SINGLE.callTypes(
			CALLTYPE_DELEGATE,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC,
			CALLTYPE_STATIC
		);

		MURPHY.account.installModule(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeModuleParams(
				abi.encode(encodeFallbackSelectors(selectors, callTypes), ""),
				abi.encodePacked(aux.mockHook, "")
			)
		);

		for (uint256 i; i < selectors.length; ++i) {
			assertTrue(
				MURPHY.account.isModuleInstalled(
					TYPE_FALLBACK,
					address(aux.mockFallback),
					abi.encodePacked(selectors[i])
				)
			);
		}

		vm.expectRevert(abi.encodeWithSelector(UnknownSelector.selector, bytes4(0xdeadbeef)));
		MURPHY.account.uninstallModule(
			TYPE_FALLBACK,
			address(aux.mockFallback),
			encodeUninstallModuleParams(abi.encode(bytes4(0xdeadbeef).bytes4s(), ""), "")
		);
	}

	function prepareEnable(
		address enableValidator,
		ModuleType moduleTypeId,
		address module,
		bytes memory initData,
		bytes memory callData,
		bool useValidSignature,
		bool useERC7739
	) internal view virtual returns (PackedUserOperation memory userOp) {
		bytes32 userOpHash;
		(userOp, userOpHash) = MURPHY.prepareUserOp(callData, module, VALIDATION_MODE_ENABLE);

		bytes32 structHash = keccak256(
			abi.encode(ENABLE_MODULE_TYPEHASH, moduleTypeId, module, keccak256(initData), userOpHash)
		);

		bytes memory enableSignature;

		if (useERC7739) {
			bytes32 typehash = keccak256(
				abi.encodePacked(
					"TypedDataSign(EnableModule contents,string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)",
					ENABLE_MODULE_NOTATION
				)
			);

			bytes32 enableModuleHash = MURPHY.account.hashTypedData(
				keccak256(
					abi.encodePacked(abi.encode(typehash, structHash), getAccountDomainStructFields(MURPHY.account))
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
			enableSignature = abi.encodePacked(
				enableValidator,
				(useValidSignature ? MURPHY : COOPER).sign(MURPHY.account.hashTypedData(structHash))
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

		userOp.signature = abi.encodePacked(enableModuleData, userOp.signature);
	}
}
