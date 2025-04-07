// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IModuleFactory {
	function deployModule(
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module);

	function deployModule(
		address registry,
		bytes32 resolverUID,
		bytes32 salt,
		bytes calldata bytecode,
		bytes calldata params
	) external payable returns (address module);

	function computeAddress(bytes32 salt, bytes calldata initCode) external view returns (address module);

	function parameters() external view returns (bytes memory context);
}
