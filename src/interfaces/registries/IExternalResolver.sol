// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC165} from "forge-std/interfaces/IERC165.sol";
import {AttestationRecord, ModuleRecord} from "./IRegistry.sol";

interface IExternalResolver is IERC165 {
	function resolveAttestation(AttestationRecord[] calldata attestation) external payable returns (bool);

	function resolveAttestation(AttestationRecord calldata attestation) external payable returns (bool);

	function resolveRevocation(AttestationRecord[] calldata attestation) external payable returns (bool);

	function resolveRevocation(AttestationRecord calldata attestation) external payable returns (bool);

	function resolveModuleRegistration(
		address sender,
		address module,
		ModuleRecord calldata record,
		bytes calldata resolverContext
	) external payable returns (bool);
}
