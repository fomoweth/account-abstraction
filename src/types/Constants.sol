// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType, ExecType, ModeSelector, ModePayload} from "./ExecutionMode.sol";
import {ModuleType, PackedModuleTypes} from "./ModuleType.sol";
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
