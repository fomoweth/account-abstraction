// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct BootstrapConfig {
	address module;
	bytes data;
}

interface IBootstrap {
	function initialize(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external;

	function initializeScoped(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external;

	function getInitializeCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory);

	function getInitializeScopedCalldata(
		BootstrapConfig calldata rootValidator,
		BootstrapConfig calldata hook,
		address registry,
		address[] calldata attesters,
		uint8 threshold
	) external view returns (bytes memory);
}
