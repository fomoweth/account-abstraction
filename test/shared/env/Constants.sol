// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IRegistry} from "src/interfaces/registries/IRegistry.sol";
import {ISmartSession} from "src/interfaces/ISmartSession.sol";
import {IPermit2} from "src/interfaces/external/uniswap/permit2/IPermit2.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ValidationData} from "src/types/ValidationData.sol";
import {ValidationMode} from "src/types/ValidationMode.sol";

abstract contract Constants {
	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	IEntryPoint internal constant ENTRYPOINT_V8 = IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
	IEntryPoint internal constant ENTRYPOINT_V7 = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
	IEntryPoint internal constant ENTRYPOINT_V6 = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

	// Rhinestone Registry
	IRegistry internal constant REGISTRY = IRegistry(0x000000000069E2a187AEFFb852bF3cCdC95151B2);

	ISmartSession internal constant SMART_SESSION = ISmartSession(0x00000000002B0eCfbD0496EE71e01257dA0E37DE);

	IPermit2 internal constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

	bytes internal constant EMPTY_MODULE_PARAMS = hex"0000000000000000";

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	bytes4 internal constant ERC1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant ERC1271_FAILED = 0xFFFFFFFF;

	bytes4 internal constant ERC7739_SUPPORTS = 0x77390000;
	bytes4 internal constant ERC7739_SUPPORTS_V1 = 0x77390001;

	bytes32 internal constant ERC7793_TYPEHASH = 0x7739773977397739773977397739773977397739773977397739773977397739;
	bytes32 internal constant ERC6492_TYPEHASH = 0x6492649264926492649264926492649264926492649264926492649264926492;

	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	ValidationMode internal constant VALIDATION_MODE_DEFAULT = ValidationMode.wrap(0x00);
	ValidationMode internal constant VALIDATION_MODE_ENABLE = ValidationMode.wrap(0x01);
	ValidationMode internal constant VALIDATION_MODE_EXECUTE = ValidationMode.wrap(0x02);
	ValidationMode internal constant VALIDATION_MODE_PREP = ValidationMode.wrap(0x03);

	ValidationData internal constant VALIDATION_SUCCESS = ValidationData.wrap(0x00);
	ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(0x01);

	ModuleType internal constant TYPE_MULTI = ModuleType.wrap(0x00);
	ModuleType internal constant TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType internal constant TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType internal constant TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType internal constant TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType internal constant TYPE_POLICY = ModuleType.wrap(0x05);
	ModuleType internal constant TYPE_SIGNER = ModuleType.wrap(0x06);
	ModuleType internal constant TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);
	ModuleType internal constant TYPE_PREVALIDATION_HOOK_ERC1271 = ModuleType.wrap(0x08);
	ModuleType internal constant TYPE_PREVALIDATION_HOOK_ERC4337 = ModuleType.wrap(0x09);

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
