// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {ModuleLib} from "src/libraries/ModuleLib.sol";
import {RegistryAdapter} from "src/core/RegistryAdapter.sol";

/// @title Bootstrap
/// @notice Provides configuration and initialization for smart accounts

contract Bootstrap is IBootstrap, RegistryAdapter {
	using ModuleLib for address;

	function initialize(
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external {
		_configureRegistry(registry, attesters, threshold);

		uint256 length = validators.length;
		for (uint256 i; i < length; ) {
			validators[i].module.installValidator(validators[i].data);

			unchecked {
				i = i + 1;
			}
		}

		length = executors.length;
		for (uint256 i; i < length; ) {
			if (executors[i].module != address(0)) executors[i].module.installExecutor(executors[i].data);

			unchecked {
				i = i + 1;
			}
		}

		length = fallbacks.length;
		for (uint256 i; i < length; ) {
			if (fallbacks[i].module != address(0)) fallbacks[i].module.installFallbackHandler(fallbacks[i].data);

			unchecked {
				i = i + 1;
			}
		}

		if (hook.module != address(0)) hook.module.installHook(hook.data);
	}

	function initializeScoped(
		BootstrapConfig[] calldata validators,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external {
		_configureRegistry(registry, attesters, threshold);

		uint256 length = validators.length;
		for (uint256 i; i < length; ) {
			validators[i].module.installValidator(validators[i].data);

			unchecked {
				i = i + 1;
			}
		}

		if (hook.module != address(0)) hook.module.installHook(hook.data);
	}

	function initializeWithSingleValidator(
		address validator,
		bytes calldata data,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external {
		_configureRegistry(registry, attesters, threshold);
		validator.installValidator(data);
	}

	function getInitializeCalldata(
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory) {
		return
			abi.encode(
				address(this),
				abi.encodeCall(
					this.initialize,
					(validators, executors, fallbacks, hook, registry, attesters, threshold)
				)
			);
	}

	function getInitializeScopedCalldata(
		BootstrapConfig[] calldata validators,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory) {
		return
			abi.encode(
				address(this),
				abi.encodeCall(this.initializeScoped, (validators, hook, registry, attesters, threshold))
			);
	}

	function getInitializeWithSingleValidatorCalldata(
		BootstrapConfig calldata validator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory) {
		return
			abi.encode(
				address(this),
				abi.encodeCall(
					this.initializeWithSingleValidator,
					(validator.module, validator.data, registry, attesters, threshold)
				)
			);
	}

	function name() external pure returns (string memory) {
		return "FomoBootstrap";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}
}
