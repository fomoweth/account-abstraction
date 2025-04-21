// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {ModuleTypeLib, ModuleType} from "src/types/ModuleType.sol";

/// @title BootstrapLib
/// @notice Provides utility functions to create BootstrapConfig structures.
library BootstrapLib {
	function build(
		address module,
		bytes memory data,
		address hook,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		return build(module, data, abi.encodePacked(hook, hookData));
	}

	function build(
		address module,
		bytes memory data,
		bytes memory hookData
	) internal pure returns (BootstrapConfig memory config) {
		config = BootstrapConfig({
			module: module,
			data: abi.encodePacked(bytes4(uint32(data.length)), data, bytes4(uint32(hookData.length)), hookData)
		});
	}

	function arrayify(BootstrapConfig memory config) internal pure returns (BootstrapConfig[] memory configs) {
		configs = new BootstrapConfig[](1);
		configs[0] = config;
	}
}
