// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {IRegistry} from "src/interfaces/registries/IRegistry.sol";
import {AttestationRequest, AttestationRecord} from "src/interfaces/registries/IRegistry.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {ResolverUID, SchemaUID} from "src/types/UID.sol";

using AttestationLib for Attester global;

struct Attester {
	address payable eoa;
	uint256 privateKey;
}

library AttestationLib {
	using ECDSA for bytes32;
	using ModuleTypeLib for ModuleType[];

	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	ResolverUID internal constant defaultResolverUID =
		ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);

	SchemaUID internal constant defaultSchemaUID =
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

		REGISTRY.attest(defaultSchemaUID, attester.eoa, request, signature);
		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);

		AttestationRecord memory record = REGISTRY.findAttestation(request.module, attester.eoa);
		vm.assertEq(record.attester, attester.eoa);
		vm.assertEq(record.module, request.module);
		vm.assertTrue(record.moduleTypes == request.moduleTypes.encode());
	}

	function attest(Attester memory attester, AttestationRequest memory request) internal {
		uint256 nonce = REGISTRY.attesterNonce(attester.eoa);

		bytes32 digest = REGISTRY.getDigest(request, attester.eoa);
		bytes memory signature = sign(attester, digest);

		REGISTRY.attest(defaultSchemaUID, attester.eoa, request, signature);
		AttestationRecord memory record = REGISTRY.findAttestation(request.module, attester.eoa);

		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);
		vm.assertEq(record.attester, attester.eoa);
		vm.assertEq(record.module, request.module);
		vm.assertTrue(record.moduleTypes == request.moduleTypes.encode());
	}

	function attest(Attester memory attester, AttestationRequest[] memory requests) internal {
		uint256 nonce = REGISTRY.attesterNonce(attester.eoa);

		bytes32 digest = REGISTRY.getDigest(requests, attester.eoa);
		bytes memory signature = sign(attester, digest);

		REGISTRY.attest(defaultSchemaUID, attester.eoa, requests, signature);

		vm.assertEq(REGISTRY.attesterNonce(attester.eoa), nonce + 1);
	}

	function build(
		address module,
		ModuleType[] memory moduleTypes,
		uint48 expirationTime
	) internal pure returns (AttestationRequest memory request) {
		request = AttestationRequest({
			module: module,
			expirationTime: expirationTime,
			data: "",
			moduleTypes: moduleTypes
		});
	}

	function build(
		address[] memory modules,
		ModuleType[][] memory moduleTypes
	) internal pure returns (AttestationRequest[] memory requests) {
		uint256 length = modules.length;
		vm.assume(length == moduleTypes.length);

		requests = new AttestationRequest[](length);
		for (uint256 i; i < length; ++i) {
			requests[i] = build(modules[i], moduleTypes[i], 0);
		}
	}

	function sign(Attester memory attester, bytes32 digest) internal pure returns (bytes memory signature) {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(attester.privateKey, digest);
		signature = abi.encodePacked(r, s, v);
	}

	function resetNonce(Attester memory attester) internal returns (uint64) {
		vm.resetNonce(attester.eoa);
		return vm.getNonce(attester.eoa);
	}

	function setNonce(Attester memory attester, uint64 nonce) internal returns (uint64) {
		uint64 current = vm.getNonce(attester.eoa);
		if (nonce == current) return nonce;

		if (nonce > current) vm.setNonce(attester.eoa, nonce);
		else vm.setNonceUnsafe(attester.eoa, nonce);

		return vm.getNonce(attester.eoa);
	}

	function getNonce(Attester memory attester) internal view returns (uint64 nonce) {
		return vm.getNonce(attester.eoa);
	}
}
