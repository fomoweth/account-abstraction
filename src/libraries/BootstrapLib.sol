// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {ModuleType} from "src/types/ModuleType.sol";

/// @title BootstrapLib
/// @notice Provides utility functions to create BootstrapConfig structures

library BootstrapLib {
	function build(address module, bytes memory data) internal pure returns (BootstrapConfig memory config) {
		config.module = module;
		config.data = data;
	}

	function build(
		address module,
		ModuleType[] memory moduleTypes,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		config.module = module;
		config.data = abi.encode(moduleTypes, data, hookData);
	}

	function arrayify(BootstrapConfig memory config) internal pure returns (BootstrapConfig[] memory configs) {
		configs = new BootstrapConfig[](1);
		configs[0] = config;
	}
}
