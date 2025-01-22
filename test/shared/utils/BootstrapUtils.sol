// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {IFallback} from "src/interfaces/IERC7579Modules.sol";
import {CallType} from "src/types/ExecutionMode.sol";

library BootstrapUtils {
	uint256 internal constant MODULE_TYPE_MULTI = 0;
	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;

	function get(
		address module,
		bytes memory data,
		uint256 moduleTypeId
	) internal view returns (BootstrapConfig memory config) {
		if (moduleTypeId == MODULE_TYPE_FALLBACK) {
			(bytes4[] memory selectors, CallType[] memory callTypes) = IFallback(module).getSupportedCalls();
			data = abi.encode(selectors, callTypes, data);
		}

		config.module = module;
		config.data = data;
	}

	function build(
		address module,
		bytes memory data,
		uint256 moduleTypeId
	) internal view returns (BootstrapConfig[] memory config) {
		config = new BootstrapConfig[](1);
		config[0] = get(module, data, moduleTypeId);
	}

	function build(
		address[] memory modules,
		bytes[] memory data,
		uint256 moduleTypeId
	) internal view returns (BootstrapConfig[] memory configs) {
		uint256 length = modules.length;
		require(length == data.length);

		configs = new BootstrapConfig[](length);
		for (uint256 i; i < length; ++i) {
			configs[i] = get(modules[i], data[i], moduleTypeId);
		}
	}
}
