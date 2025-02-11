// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IRegistry, IExternalResolver, IExternalSchemaValidator} from "src/interfaces/registries/IRegistry.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ResolverUID, SchemaUID} from "src/types/UID.sol";

abstract contract Constants is CommonBase {
	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;
	uint192 internal constant MAX_UINT192 = (1 << 192) - 1;
	uint160 internal constant MAX_UINT160 = (1 << 160) - 1;
	uint104 internal constant MAX_UINT104 = (1 << 104) - 1;
	uint48 internal constant MAX_UINT48 = (1 << 48) - 1;

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	bytes32 internal constant STETH_TOTAL_SHARES_SLOT =
		0xe3b4b636e601189b5f4c6742edf2538ac12bb61ed03e6da26949d69838fa447e;

	bytes32 internal constant ERC7739_SUPPORTS_HASH =
		0x7739773977397739773977397739773977397739773977397739773977397739;

	bytes4 internal constant ERC7739_SUPPORTS = 0x77390000;
	bytes4 internal constant ERC7739_SUPPORTS_V1 = 0x77390001;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	uint256 internal constant VALIDATION_SUCCESS = 0;
	uint256 internal constant VALIDATION_FAILED = 1;

	bytes1 internal constant FLAG_DEFAULT = 0x00;
	bytes1 internal constant FLAG_ENFORCE = 0xff;

	ModuleType internal constant TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);

	IMulticall3 internal constant MULTICALL3 = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	address internal constant SMART_SESSION = 0x00000000002B0eCfbD0496EE71e01257dA0E37DE;

	// Rhinestone Registry
	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	// Rhinestone Resolver
	IExternalResolver internal constant DEFAULT_RESOLVER =
		IExternalResolver(0xF0f468571e764664c93308504642aF941d9f77F1);

	ResolverUID internal constant DEFAULT_RESOLVER_UID =
		ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);

	// Rhinestone Schema Validator
	IExternalSchemaValidator internal constant DEFAULT_SCHEMA =
		IExternalSchemaValidator(0x86430E19D7D204807bBb8CDa997bb57b7EE785dD);

	SchemaUID internal constant DEFAULT_SCHEMA_UID =
		SchemaUID.wrap(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1);
}
