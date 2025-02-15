// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/Constants.sol";
import {AccountModule} from "src/core/AccountModule.sol";

/// @title Bootstrap
/// @notice Provides configuration and initialization for smart accounts

contract Bootstrap is IBootstrap, AccountModule {
	function initialize(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external {
		_configureRegistry(registry, attesters, threshold);
		_configureRootValidator(rootValidator.module, rootValidator.data);
		_installModule(MODULE_TYPE_HOOK, hook.module, hook.data);

		uint256 length = validators.length;
		for (uint256 i; i < length; ) {
			_installModule(MODULE_TYPE_VALIDATOR, validators[i].module, validators[i].data);

			unchecked {
				i = i + 1;
			}
		}

		length = executors.length;
		for (uint256 i; i < length; ) {
			_installModule(MODULE_TYPE_EXECUTOR, executors[i].module, executors[i].data);

			unchecked {
				i = i + 1;
			}
		}

		length = fallbacks.length;
		for (uint256 i; i < length; ) {
			_installModule(MODULE_TYPE_FALLBACK, fallbacks[i].module, fallbacks[i].data);

			unchecked {
				i = i + 1;
			}
		}
	}

	function initializeScoped(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external {
		_configureRegistry(registry, attesters, threshold);
		_configureRootValidator(rootValidator.module, rootValidator.data);
		_installModule(MODULE_TYPE_HOOK, hook.module, hook.data);
	}

	function getInitializeCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData) {
		callData = abi.encodePacked(
			address(this),
			abi.encodeCall(
				this.initialize,
				(rootValidator, hook, validators, executors, fallbacks, registry, attesters, threshold)
			)
		);
	}

	function getInitializeScopedCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData) {
		callData = abi.encodePacked(
			address(this),
			abi.encodeCall(this.initializeScoped, (rootValidator, hook, registry, attesters, threshold))
		);
	}

	function name() public pure virtual returns (string memory) {
		return "VortexBootstrap";
	}

	function version() public pure virtual returns (string memory) {
		return "1.0.0";
	}
}
