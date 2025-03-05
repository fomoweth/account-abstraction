// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";

/// @title BootstrapLib
/// @notice Provides utility functions to create BootstrapConfig structures

library BootstrapLib {
	using ModuleTypeLib for ModuleType[];

	function build(address module, bytes memory data) internal pure returns (BootstrapConfig memory config) {
		config.module = module;
		config.data = data;
	}

	function build(
		address module,
		ModuleType moduleTypeId,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		return build(module, moduleTypeId.arrayify().encode(), data, hookData);
	}

	function build(
		address module,
		ModuleType[] memory moduleTypeIds,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		return build(module, moduleTypeIds.encode(), data, hookData);
	}

	function build(
		address module,
		PackedModuleTypes packedTypes,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		config.module = module;
		config.data = abi.encodePacked(
			packedTypes,
			bytes4(uint32(data.length)),
			data,
			bytes4(uint32(hookData.length)),
			hookData
		);
	}

	function arrayify(BootstrapConfig memory config) internal pure returns (BootstrapConfig[] memory configs) {
		configs = new BootstrapConfig[](1);
		configs[0] = config;
	}
}
