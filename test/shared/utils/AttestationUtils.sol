// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AttestationRequest, ModuleType} from "src/interfaces/registries/IRegistry.sol";
import {Calldata} from "src/libraries/Calldata.sol";

library AttestationUtils {
	error LengthMismatch();

	function build(
		address module,
		ModuleType moduleType,
		uint48 expirationTime
	) internal pure returns (AttestationRequest memory request) {
		ModuleType[] memory moduleTypes = new ModuleType[](1);
		moduleTypes[0] = moduleType;

		return build(module, moduleTypes, expirationTime);
	}

	function build(
		address module,
		ModuleType[] memory moduleTypes,
		uint48 expirationTime
	) internal pure returns (AttestationRequest memory request) {
		request = AttestationRequest({
			module: module,
			expirationTime: expirationTime,
			data: Calldata.emptyBytes(),
			moduleTypes: moduleTypes
		});
	}

	function build(
		address[] memory modules,
		ModuleType[] memory moduleTypes
	) internal pure returns (AttestationRequest[] memory requests) {
		uint256 length = modules.length;
		require(length == moduleTypes.length, LengthMismatch());

		requests = new AttestationRequest[](length);
		for (uint256 i; i < length; ++i) {
			requests[i] = build(modules[i], moduleTypes[i], 0);
		}
	}

	function build(
		address[] memory modules,
		ModuleType[] memory moduleTypes,
		uint48[] memory expirationTimes
	) internal pure returns (AttestationRequest[] memory requests) {
		uint256 length = modules.length;
		require(length == moduleTypes.length && length == expirationTimes.length, LengthMismatch());

		requests = new AttestationRequest[](length);
		for (uint256 i; i < length; ++i) {
			requests[i] = build(modules[i], moduleTypes[i], expirationTimes[i]);
		}
	}

	function build(
		address[] memory modules,
		ModuleType[][] memory moduleTypes
	) internal pure returns (AttestationRequest[] memory requests) {
		uint256 length = modules.length;
		require(length == moduleTypes.length, LengthMismatch());

		requests = new AttestationRequest[](length);
		for (uint256 i; i < length; ++i) {
			requests[i] = build(modules[i], moduleTypes[i], 0);
		}
	}

	function build(
		address[] memory modules,
		ModuleType[][] memory moduleTypes,
		uint48[] memory expirationTimes
	) internal pure returns (AttestationRequest[] memory requests) {
		uint256 length = modules.length;
		require(length == moduleTypes.length && length == expirationTimes.length, LengthMismatch());

		requests = new AttestationRequest[](length);
		for (uint256 i; i < length; ++i) {
			requests[i] = build(modules[i], moduleTypes[i], expirationTimes[i]);
		}
	}
}
