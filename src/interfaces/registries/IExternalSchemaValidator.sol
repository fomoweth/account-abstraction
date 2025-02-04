// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC165} from "forge-std/interfaces/IERC165.sol";
import {AttestationRecord} from "./IRegistry.sol";

interface IExternalSchemaValidator is IERC165 {
	function validateSchema(AttestationRecord[] calldata attestations) external returns (bool);

	function validateSchema(AttestationRecord calldata attestation) external returns (bool);
}
