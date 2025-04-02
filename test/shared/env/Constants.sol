// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {SenderCreator} from "account-abstraction/core/SenderCreator.sol";
import {IPermit2} from "src/interfaces/external/uniswap/permit2/IPermit2.sol";
import {IRegistry, IExternalResolver, IExternalSchemaValidator} from "src/interfaces/registries/IRegistry.sol";
import {ISmartSession} from "src/interfaces/ISmartSession.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {ResolverUID, SchemaUID} from "src/types/UID.sol";
import {ValidationData} from "src/types/ValidationData.sol";
import {ValidationMode} from "src/types/ValidationMode.sol";

abstract contract Constants is CommonBase {
	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	IPermit2 internal constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

	SenderCreator internal constant SENDER_CREATOR = SenderCreator(0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C);

	ISmartSession internal constant SMART_SESSION = ISmartSession(0x00000000002B0eCfbD0496EE71e01257dA0E37DE);

	// Rhinestone Registry
	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	// Rhinestone Resolver
	IExternalResolver internal constant RESOLVER = IExternalResolver(0xF0f468571e764664c93308504642aF941d9f77F1);

	ResolverUID internal constant RESOLVER_UID =
		ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);

	// Rhinestone Schema Validator
	IExternalSchemaValidator internal constant SCHEMA =
		IExternalSchemaValidator(0x86430E19D7D204807bBb8CDa997bb57b7EE785dD);

	SchemaUID internal constant SCHEMA_UID =
		SchemaUID.wrap(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1);

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	ValidationData internal constant VALIDATION_SUCCESS = ValidationData.wrap(0x00);
	ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(0x01);

	ValidationMode internal constant VALIDATION_MODE_DEFAULT = ValidationMode.wrap(0x00);
	ValidationMode internal constant VALIDATION_MODE_ENABLE = ValidationMode.wrap(0x01);

	bytes1 internal constant FLAG_DEFAULT = 0x00;
	bytes1 internal constant FLAG_SKIP = 0x01;
	bytes1 internal constant FLAG_ENFORCE = 0xff;

	ModuleType internal constant TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);

	PackedModuleTypes internal constant PACKED_VALIDATOR = PackedModuleTypes.wrap(0x02);
	PackedModuleTypes internal constant PACKED_EXECUTOR = PackedModuleTypes.wrap(0x04);
	PackedModuleTypes internal constant PACKED_FALLBACK = PackedModuleTypes.wrap(0x08);
	PackedModuleTypes internal constant PACKED_HOOK = PackedModuleTypes.wrap(0x10);
	PackedModuleTypes internal constant PACKED_POLICY = PackedModuleTypes.wrap(0x20);
	PackedModuleTypes internal constant PACKED_SIGNER = PackedModuleTypes.wrap(0x40);
	PackedModuleTypes internal constant PACKED_STATELESS_VALIDATOR = PackedModuleTypes.wrap(0x80);
	PackedModuleTypes internal constant PACKED_HYBRID_VALIDATOR = PackedModuleTypes.wrap(0x82);

	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;
	uint192 internal constant MAX_UINT192 = (1 << 192) - 1;
	uint160 internal constant MAX_UINT160 = (1 << 160) - 1;
	uint128 internal constant MAX_UINT128 = (1 << 128) - 1;
	uint104 internal constant MAX_UINT104 = (1 << 104) - 1;
	uint48 internal constant MAX_UINT48 = (1 << 48) - 1;
	uint40 internal constant DEADLINE = 2000000000;

	uint24 internal constant FEE_LOWEST = 100;
	uint24 internal constant FEE_LOW = 500;
	uint24 internal constant FEE_MEDIUM = 3000;
	uint24 internal constant FEE_HIGH = 10000;
}
