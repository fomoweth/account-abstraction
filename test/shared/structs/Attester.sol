// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IRegistry, AttestationRequest} from "src/interfaces/registries/IRegistry.sol";
import {ModuleType, SchemaUID} from "src/types/Types.sol";

using AttestationLib for Attester global;

struct Attester {
	address payable eoa;
	uint256 privateKey;
}

library AttestationLib {
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
		bytes memory signature = attester.sign(digest);

		REGISTRY.attest(SCHEMA_UID, attester.eoa, request, signature);
		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);
	}

	function attest(Attester memory attester, address[] memory modules, ModuleType[][] memory moduleTypes) internal {
		uint256 length = modules.length;
		vm.assertEq(length, moduleTypes.length);

		AttestationRequest[] memory requests = new AttestationRequest[](length);

		for (uint256 i; i < length; ++i) {
			requests[i] = AttestationRequest({
				module: modules[i],
				expirationTime: 0,
				data: "",
				moduleTypes: moduleTypes[i]
			});
		}

		uint256 nonce = REGISTRY.attesterNonce(attester.eoa);
		bytes32 digest = REGISTRY.getDigest(requests, attester.eoa);
		bytes memory signature = attester.sign(digest);

		REGISTRY.attest(SCHEMA_UID, attester.eoa, requests, signature);
		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);
	}

	function sign(Attester memory attester, bytes32 hash) internal pure returns (bytes memory signature) {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(attester.privateKey, hash);
		return bytes.concat(r, s, bytes1(v));
	}
}
