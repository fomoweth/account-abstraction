// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {ModuleTypeLib, ModuleType} from "src/types/ModuleType.sol";
import {Calldata} from "./Calldata.sol";

/// @title BootstrapLib
/// @notice Provides utility functions to create BootstrapConfig structures

library BootstrapLib {
	using ModuleTypeLib for ModuleType[];

	function build(address module, ModuleType moduleTypeId) internal pure returns (BootstrapConfig memory config) {
		return build(module, moduleTypeId, arrayify(moduleTypeId), Calldata.emptyBytes(), Calldata.emptyBytes());
	}

	function build(
		address module,
		ModuleType moduleTypeId,
		bytes memory data
	) internal pure returns (BootstrapConfig memory config) {
		return build(module, moduleTypeId, arrayify(moduleTypeId), data, Calldata.emptyBytes());
	}

	function build(
		address module,
		ModuleType moduleTypeId,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		return build(module, moduleTypeId, arrayify(moduleTypeId), data, hookData);
	}

	function build(
		address module,
		ModuleType moduleTypeId,
		ModuleType[] memory moduleTypes,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		require(moduleTypes.encode().isType(moduleTypeId), Errors.InvalidModuleTypeId(moduleTypeId));

		if (moduleTypeId != MODULE_TYPE_HOOK) {
			data = abi.encode(data, hookData);
		}

		config.module = module;
		config.data = abi.encode(moduleTypes, data);
	}

	function arrayify(BootstrapConfig memory config) internal pure returns (BootstrapConfig[] memory configs) {
		configs = new BootstrapConfig[](1);
		configs[0] = config;
	}

	function arrayify(ModuleType moduleTypeId) internal pure returns (ModuleType[] memory moduleTypes) {
		moduleTypes = new ModuleType[](1);
		moduleTypes[0] = moduleTypeId;
	}
}
