// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct BootstrapConfig {
	address module;
	bytes data;
}

interface IBootstrap {
	function initialize(
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external;

	function initializeScoped(
		BootstrapConfig[] calldata validators,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external;

	function initializeWithSingleValidator(
		address validator,
		bytes calldata data,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external;

	function getInitializeCalldata(
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory);

	function getInitializeScopedCalldata(
		BootstrapConfig[] calldata validators,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory);

	function getInitializeWithSingleValidatorCalldata(
		BootstrapConfig calldata validator,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory);
}
