// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {NativeWrapperFallback} from "src/modules/fallbacks/NativeWrapperFallback.sol";
import {STETHWrapperFallback} from "src/modules/fallbacks/STETHWrapperFallback.sol";
import {K1Validator} from "src/modules/validators/K1Validator.sol";
import {ModuleFactory} from "src/factories/ModuleFactory.sol";

import {BaseTest} from "test/shared/env/BaseTest.sol";

contract ModuleFactoryTest is BaseTest {
	function setUp() public virtual override {
		super.setUp();
	}

	function setUpContracts() internal virtual override impersonate(ADMIN, false) {
		aux.moduleFactory = new ModuleFactory{salt: SALT}(address(REGISTRY));
	}

	function test_deployModule() public virtual {
		bytes memory bytecode = type(NativeWrapperFallback).creationCode;
		bytes memory params = abi.encode(WNATIVE);
		bytes memory initCode = abi.encodePacked(bytecode, params);

		address expected = aux.moduleFactory.computeAddress(SALT, initCode);
		address deployed = aux.moduleFactory.deployModule(SALT, bytecode, params);
		assertEq(deployed, expected);

		assertEq(NativeWrapperFallback(deployed).WRAPPED_NATIVE(), WNATIVE);
	}

	function test_deployModule_withParameters() public virtual onlyEthereum {
		bytes memory bytecode = type(STETHWrapperFallback).creationCode;
		bytes memory params = abi.encode(STETH, WSTETH);
		bytes memory initCode = abi.encodePacked(bytecode, params);

		address expected = aux.moduleFactory.computeAddress(SALT, initCode);
		address deployed = aux.moduleFactory.deployModule(SALT, bytecode, params);
		assertEq(deployed, expected);

		assertEq(STETHWrapperFallback(deployed).STETH(), STETH);
		assertEq(STETHWrapperFallback(deployed).WSTETH(), WSTETH);
	}

	function test_deployModule_withoutParameters() public virtual {
		bytes memory bytecode = type(K1Validator).creationCode;

		address expected = aux.moduleFactory.computeAddress(SALT, bytecode);
		address deployed = aux.moduleFactory.deployModule(SALT, bytecode, "");
		assertEq(deployed, expected);
	}
}
