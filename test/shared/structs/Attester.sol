// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IRegistry, AttestationRecord, AttestationRequest} from "src/interfaces/registries/IRegistry.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {SchemaUID} from "src/types/UID.sol";

using AttestationLib for Attester global;

struct Attester {
	address payable eoa;
	uint256 privateKey;
}

library AttestationLib {
	using ModuleTypeLib for ModuleType[];

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	SchemaUID internal constant SCHEMA_UID =
		SchemaUID.wrap(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1);

	function attest(Attester memory attester, address module, ModuleType[] memory moduleTypes) internal {
		AttestationRequest memory request = AttestationRequest({
			module: module,
			expirationTime: 0,
			data: "",
			moduleTypes: moduleTypes
		});

		uint256 nonce = REGISTRY.attesterNonce(attester.eoa);
		bytes32 digest = REGISTRY.getDigest(request, attester.eoa);
		bytes memory signature = sign(attester, digest);

		REGISTRY.attest(SCHEMA_UID, attester.eoa, request, signature);
		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);

		AttestationRecord memory record = REGISTRY.findAttestation(request.module, attester.eoa);
		vm.assertEq(record.attester, attester.eoa);
		vm.assertEq(record.module, request.module);
		vm.assertTrue(record.moduleTypes == request.moduleTypes.encode());
	}

	function sign(Attester memory attester, bytes32 hash) internal pure returns (bytes memory signature) {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(attester.privateKey, hash);
		return bytes.concat(r, s, bytes1(v));
	}
}
