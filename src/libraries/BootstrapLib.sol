// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {ModuleTypeLib, ModuleType} from "src/types/ModuleType.sol";

/// @title BootstrapLib
/// @notice Provides utility functions to create BootstrapConfig structures

library BootstrapLib {
	using ModuleTypeLib for ModuleType[];

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

	function build(
		address[] memory modules,
		ModuleType[] memory moduleTypeIds,
		ModuleType[][] memory moduleTypes,
		bytes[] memory data,
		bytes[] memory hookData
	) internal pure returns (BootstrapConfig[] memory configs) {
		uint256 length = modules.length;
		require(
			length == moduleTypeIds.length &&
				length == moduleTypes.length &&
				length == data.length &&
				length == hookData.length,
			Errors.LengthMismatch()
		);

		configs = new BootstrapConfig[](length);
		for (uint256 i; i < length; ) {
			configs[i] = build(modules[i], moduleTypeIds[i], moduleTypes[i], data[i], hookData[i]);

			unchecked {
				i = i + 1;
			}
		}
	}

	function arrayify(BootstrapConfig memory config) internal pure returns (BootstrapConfig[] memory configs) {
		configs = new BootstrapConfig[](1);
		configs[0] = config;
	}
}
