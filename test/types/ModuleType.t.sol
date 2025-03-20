// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {Constants} from "test/shared/env/Constants.sol";

contract ModuleTypeTest is Test, Constants {
	using ModuleTypeLib for ModuleType[];
	using SolArray for ModuleType;

	ModuleType[][] moduleTypeIds;
	ModuleType[][] remainTypeIds;

	function setUp() public virtual {
		moduleTypeIds = new ModuleType[][](4);
		remainTypeIds = new ModuleType[][](4);

		moduleTypeIds[0] = TYPE_VALIDATOR.moduleTypes(TYPE_EXECUTOR, TYPE_FALLBACK, TYPE_HOOK);
		remainTypeIds[0] = TYPE_POLICY.moduleTypes(TYPE_SIGNER, TYPE_STATELESS_VALIDATOR);

		moduleTypeIds[1] = TYPE_VALIDATOR.moduleTypes(TYPE_POLICY, TYPE_SIGNER, TYPE_STATELESS_VALIDATOR);
		remainTypeIds[1] = TYPE_FALLBACK.moduleTypes(TYPE_EXECUTOR, TYPE_HOOK);

		moduleTypeIds[2] = TYPE_VALIDATOR.moduleTypes(TYPE_STATELESS_VALIDATOR);
		remainTypeIds[2] = TYPE_FALLBACK.moduleTypes(TYPE_EXECUTOR, TYPE_HOOK);

		moduleTypeIds[3] = TYPE_FALLBACK.moduleTypes(TYPE_EXECUTOR, TYPE_HOOK);
		remainTypeIds[3] = TYPE_VALIDATOR.moduleTypes(TYPE_POLICY, TYPE_SIGNER, TYPE_STATELESS_VALIDATOR);
	}

	function test_encode() public virtual {
		for (uint256 i; i < moduleTypeIds.length; ++i) {
			_validateEncode(moduleTypeIds[i], remainTypeIds[i]);
		}
	}

	function test_decode() public virtual {
		for (uint256 i; i < moduleTypeIds.length; ++i) {
			_validateDecode(moduleTypeIds[i]);
		}
	}

	function _validateEncode(ModuleType[] memory moduleTypes, ModuleType[] memory remainTypes) internal pure virtual {
		PackedModuleTypes packedTypes = moduleTypes.encode();
		assertEq(packedTypes.numberOfTypes(), moduleTypes.length);

		for (uint256 i; i < moduleTypes.length; ++i) {
			assertTrue(packedTypes.isType(moduleTypes[i]));
		}

		for (uint256 i; i < remainTypes.length; ++i) {
			assertFalse(packedTypes.isType(remainTypes[i]));
		}
	}

	function _validateDecode(ModuleType[] memory moduleTypes) internal pure virtual {
		PackedModuleTypes packedTypes = moduleTypes.encode();
		assertEq(packedTypes.numberOfTypes(), moduleTypes.length);

		ModuleType[] memory decodedTypes = packedTypes.decode();
		assertEq(packedTypes.numberOfTypes(), decodedTypes.length);

		for (uint256 i; i < moduleTypes.length; ++i) {
			assertTrue(packedTypes.isType(decodedTypes[i]));
		}
	}
}
