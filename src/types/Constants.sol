// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType, ExecType, ModeSelector, ModePayload} from "./ExecutionMode.sol";
import {ModuleType, PackedModuleTypes} from "./ModuleType.sol";
import {ActionId} from "./Session.sol";
import {ResolverUID, SchemaUID} from "./UID.sol";
import {ValidationData} from "./ValidationData.sol";

CallType constant CALLTYPE_SINGLE = CallType.wrap(0x00);
CallType constant CALLTYPE_BATCH = CallType.wrap(0x01);
CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);
CallType constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

ExecType constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
ExecType constant EXECTYPE_TRY = ExecType.wrap(0x01);

ModeSelector constant MODE_SELECTOR_DEFAULT = ModeSelector.wrap(bytes4(0x00000000));
ModeSelector constant MODE_SELECTOR_OFFSET = ModeSelector.wrap(0xeda86f9b); // bytes4(keccak256("default.mode.offset"))
ModePayload constant MODE_PAYLOAD_DEFAULT = ModePayload.wrap(bytes22(0));

ModuleType constant MODULE_TYPE_VALIDATOR = ModuleType.wrap(0x01);
ModuleType constant MODULE_TYPE_EXECUTOR = ModuleType.wrap(0x02);
ModuleType constant MODULE_TYPE_FALLBACK = ModuleType.wrap(0x03);
ModuleType constant MODULE_TYPE_HOOK = ModuleType.wrap(0x04);
ModuleType constant MODULE_TYPE_POLICY = ModuleType.wrap(0x05);
ModuleType constant MODULE_TYPE_SIGNER = ModuleType.wrap(0x06);
ModuleType constant MODULE_TYPE_STATELESS_VALIDATOR = ModuleType.wrap(0x07);

ValidationData constant VALIDATION_SUCCESS = ValidationData.wrap(0x00);
ValidationData constant VALIDATION_FAILED = ValidationData.wrap(0x01);

// A unique ValidationData value to retry a policy check with the FALLBACK_ACTION_ID.
ValidationData constant RETRY_WITH_FALLBACK = ValidationData.wrap(uint256(0x50FFBAAD));

// keccak256(abi.encodePacked(FALLBACK_TARGET_FLAG, FALLBACK_TARGET_SELECTOR_FLAG))
ActionId constant FALLBACK_ACTION_ID = ActionId.wrap(
	0xd884b6afa19f8ace90a388daca691e4e28f20cdac5aeefd46ad8bd1c074d28cf
);

// keccak256(abi.encodePacked(FALLBACK_TARGET_FLAG, FALLBACK_TARGET_SELECTOR_FLAG_PERMITTED_TO_CALL_SMARTSESSION))
ActionId constant FALLBACK_ACTION_ID_SMART_SESSION_CALL = ActionId.wrap(
	0x986126569d6396d837d7adeb3ca726199afaf83546f38726e6f331bb92d8e9d6
);

address constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

address constant SMART_SESSION = 0x00000000002B0eCfbD0496EE71e01257dA0E37DE;

// Rhinestone Registry
address constant REGISTRY = 0x000000000069E2a187AEFFb852bF3cCdC95151B2;

// Rhinestone Resolver
address constant DEFAULT_RESOLVER = 0xF0f468571e764664c93308504642aF941d9f77F1;

ResolverUID constant DEFAULT_RESOLVER_UID = ResolverUID.wrap(
	0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f
);

// Rhinestone Schema Validator
address constant DEFAULT_SCHEMA = 0x86430E19D7D204807bBb8CDa997bb57b7EE785dD;

SchemaUID constant DEFAULT_SCHEMA_UID = SchemaUID.wrap(
	0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1
);
