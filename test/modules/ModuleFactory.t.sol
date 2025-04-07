// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {NativeWrapper} from "src/modules/fallbacks/NativeWrapper.sol";
import {STETHWrapper} from "src/modules/fallbacks/STETHWrapper.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";
import {Deploy} from "test/shared/utils/Deploy.sol";

contract ModuleFactoryTest is BaseTest {
	function setUp() public virtual override {
		super.setUp();
	}

	function setUpContracts() internal virtual override impersonate(ADMIN, false) {
		MODULE_FACTORY = Deploy.moduleFactory(SALT, address(REGISTRY), RESOLVER_UID);
	}

	function test_deployModule() public virtual {
		bytes memory bytecode = type(NativeWrapper).creationCode;
		bytes memory params = abi.encode(WNATIVE);
		bytes memory initCode = abi.encodePacked(bytecode, params);

		address expected = MODULE_FACTORY.computeAddress(SALT, initCode);
		address deployed = MODULE_FACTORY.deployModule(SALT, bytecode, params);
		assertEq(deployed, expected);

		assertEq(NativeWrapper(deployed).WRAPPED_NATIVE(), WNATIVE);
	}

	function test_deployModule_withParameters() public virtual {
		bytes memory bytecode = type(STETHWrapper).creationCode;
		bytes memory params = abi.encode(STETH, WSTETH);
		bytes memory initCode = abi.encodePacked(bytecode, params);

		address expected = MODULE_FACTORY.computeAddress(SALT, initCode);
		address deployed = MODULE_FACTORY.deployModule(SALT, bytecode, params);
		assertEq(deployed, expected);

		assertEq(STETHWrapper(deployed).STETH(), STETH);
		assertEq(STETHWrapper(deployed).WSTETH(), WSTETH);
	}

	function test_deployModule_withoutParameters() public virtual {
		bytes memory bytecode = type(K1Validator).creationCode;

		address expected = MODULE_FACTORY.computeAddress(SALT, bytecode);
		address deployed = MODULE_FACTORY.deployModule(SALT, bytecode, "");
		assertEq(deployed, expected);
	}
}
