// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {ModuleManager} from "src/core/ModuleManager.sol";

/// @title Bootstrap
/// @notice Provides configuration and initialization for smart accounts
contract Bootstrap is IBootstrap, ModuleManager {
	/// @inheritdoc IBootstrap
	function initialize(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable {
		if (registry != address(0)) _configureRegistry(registry, attesters, threshold);
		_configureRootValidator(rootValidator.module, rootValidator.data);

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

		length = hooks.length;
		for (uint256 i; i < length; ) {
			_installModule(MODULE_TYPE_HOOK, hooks[i].module, hooks[i].data);

			unchecked {
				i = i + 1;
			}
		}

		if (preValidationHook1271.module != address(0)) {
			_installModule(
				MODULE_TYPE_PREVALIDATION_HOOK_ERC1271,
				preValidationHook1271.module,
				preValidationHook1271.data
			);
		}

		if (preValidationHook4337.module != address(0)) {
			_installModule(
				MODULE_TYPE_PREVALIDATION_HOOK_ERC4337,
				preValidationHook4337.module,
				preValidationHook4337.data
			);
		}
	}

	/// @inheritdoc IBootstrap
	function initializeScoped(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable {
		if (registry != address(0)) _configureRegistry(registry, attesters, threshold);
		_configureRootValidator(rootValidator.module, rootValidator.data);

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

		length = hooks.length;
		for (uint256 i; i < length; ) {
			_installModule(MODULE_TYPE_HOOK, hooks[i].module, hooks[i].data);

			unchecked {
				i = i + 1;
			}
		}
	}

	/// @inheritdoc IBootstrap
	function initializeWithRootValidator(
		BootstrapConfig calldata rootValidator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external payable {
		if (registry != address(0)) _configureRegistry(registry, attesters, threshold);
		_configureRootValidator(rootValidator.module, rootValidator.data);
	}

	/// @inheritdoc IBootstrap
	function getInitializeCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData) {
		callData = abi.encodePacked(
			address(this),
			abi.encodeCall(
				this.initialize,
				(
					rootValidator,
					validators,
					executors,
					fallbacks,
					hooks,
					preValidationHook1271,
					preValidationHook4337,
					registry,
					attesters,
					threshold
				)
			)
		);
	}

	/// @inheritdoc IBootstrap
	function getInitializeScopedCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData) {
		callData = abi.encodePacked(
			address(this),
			abi.encodeCall(
				this.initializeScoped,
				(rootValidator, validators, executors, fallbacks, hooks, registry, attesters, threshold)
			)
		);
	}

	/// @inheritdoc IBootstrap
	function getInitializeWithRootValidatorCalldata(
		BootstrapConfig calldata rootValidator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory callData) {
		callData = abi.encodePacked(
			address(this),
			abi.encodeCall(this.initializeWithRootValidator, (rootValidator, registry, attesters, threshold))
		);
	}

	/// @notice Returns the name of the the contract
	/// @return The name of the the contract
	function name() external pure returns (string memory) {
		return "Bootstrap";
	}

	/// @notice Returns the version of the the contract
	/// @return The version of the the contract
	function version() external pure returns (string memory) {
		return "1.0.0";
	}
}
