// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {SolArray} from "test/shared/utils/SolArray.sol";
import {Constants} from "test/shared/env/Constants.sol";

// forge test --match-path test/types/ModuleType.t.sol -vvv

contract ModuleTypeTest is Test, Constants {
	using ModuleTypeLib for ModuleType[];

	ModuleType[] moduleTypes;

	function setUp() public virtual {
		moduleTypes = SolArray.moduleTypes(
			TYPE_VALIDATOR,
			TYPE_EXECUTOR,
			TYPE_FALLBACK,
			TYPE_HOOK,
			TYPE_STATELESS_VALIDATOR
		);
	}

	function test_encode() public virtual {
		PackedModuleTypes packed = moduleTypes.encode();
		assertEq(packed.numberOfTypes(), moduleTypes.length);

		for (uint256 i; i < moduleTypes.length; ++i) {
			assertTrue(packed.isType(moduleTypes[i]));
		}

		assertFalse(packed.isType(TYPE_POLICY));
		assertFalse(packed.isType(TYPE_SIGNER));
	}

	function test_decode() public virtual {
		PackedModuleTypes packed = moduleTypes.encode();
		assertEq(packed.numberOfTypes(), moduleTypes.length);

		ModuleType[] memory ids = packed.decode();
		assertEq(ids.length, packed.numberOfTypes());

		for (uint256 i; i < moduleTypes.length; ++i) {
			assertEq(ModuleType.unwrap(ids[i]), ModuleType.unwrap(moduleTypes[i]));
		}
	}
}
