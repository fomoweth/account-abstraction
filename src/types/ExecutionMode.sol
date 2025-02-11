// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_STATIC, CALLTYPE_DELEGATE} from "src/types/Constants.sol";
import {EXECTYPE_DEFAULT, EXECTYPE_TRY} from "src/types/Constants.sol";
import {MODE_SELECTOR_DEFAULT, MODE_PAYLOAD_DEFAULT} from "src/types/Constants.sol";

type ExecutionMode is bytes32;

type CallType is bytes1;

type ExecType is bytes1;

type ModeSelector is bytes4;

type ModePayload is bytes22;

using ExecutionModeLib for ExecutionMode global;
using {eqCallType as ==, neqCallType as !=} for CallType global;
using {eqExecType as ==, neqExecType as !=} for ExecType global;
using {eqModeSelector as ==, neqModeSelector as !=} for ModeSelector global;
using {eqModePayload as ==, neqModePayload as !=} for ModePayload global;

function eqCallType(CallType x, CallType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqCallType(CallType x, CallType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqExecType(ExecType x, ExecType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqExecType(ExecType x, ExecType y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqModeSelector(ModeSelector x, ModeSelector y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqModeSelector(ModeSelector x, ModeSelector y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function eqModePayload(ModePayload x, ModePayload y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neqModePayload(ModePayload x, ModePayload y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

/// @title ExecutionModeLib
/// @notice Provides functions to encode and decode execution mode

library ExecutionModeLib {
	function encode(
		CallType callType,
		ExecType execType,
		ModeSelector selector,
		ModePayload payload
	) internal pure returns (ExecutionMode mode) {
		assembly ("memory-safe") {
			mode := or(shl(0x08, byte(0x00, callType)), byte(0x00, execType))
			mode := or(shr(0xe0, selector), shl(0x40, mode))
			mode := or(shr(0x50, payload), shl(0xb0, mode))
		}
	}

	function decode(
		ExecutionMode mode
	) internal pure returns (CallType callType, ExecType execType, ModeSelector selector, ModePayload payload) {
		assembly ("memory-safe") {
			callType := shl(0xf8, shr(0xf8, mode))
			execType := shl(0xf8, shr(0xf8, shl(0x08, mode)))
			selector := shl(0xe0, shr(0xe0, shl(0x30, mode)))
			payload := shl(0x50, mode)
		}
	}

	function parseTypes(ExecutionMode mode) internal pure returns (CallType callType, ExecType execType) {
		assembly ("memory-safe") {
			callType := shl(0xf8, shr(0xf8, mode))
			execType := shl(0xf8, shr(0xf8, shl(0x08, mode)))

			if iszero(or(iszero(callType), or(eq(callType, shl(0xf8, 0x01)), eq(callType, shl(0xf8, 0xFF))))) {
				mstore(0x00, 0xb96fcfe4) // UnsupportedCallType(bytes1)
				mstore(0x20, callType)
				revert(0x1c, 0x24)
			}

			if iszero(or(iszero(execType), eq(execType, shl(0xf8, 0x01)))) {
				mstore(0x00, 0x1187dc06) // UnsupportedExecType(bytes1)
				mstore(0x20, execType)
				revert(0x1c, 0x24)
			}
		}
	}

	function parseCallType(ExecutionMode mode) internal pure returns (CallType callType) {
		assembly ("memory-safe") {
			callType := mode
		}
	}

	function parseExecType(ExecutionMode mode) internal pure returns (ExecType execType) {
		assembly ("memory-safe") {
			execType := shl(0x08, mode)
		}
	}

	function parseSelector(ExecutionMode mode) internal pure returns (ModeSelector selector) {
		assembly ("memory-safe") {
			selector := shl(0x30, mode)
		}
	}

	function parsePayload(ExecutionMode mode) internal pure returns (ModePayload payload) {
		assembly ("memory-safe") {
			payload := shl(0x50, mode)
		}
	}

	function encodeSingle() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_SINGLE, EXECTYPE_DEFAULT);
	}

	function encodeTrySingle() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_SINGLE, EXECTYPE_TRY);
	}

	function encodeBatch() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_BATCH, EXECTYPE_DEFAULT);
	}

	function encodeTryBatch() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_BATCH, EXECTYPE_TRY);
	}

	function encodeDelegate() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_DELEGATE, EXECTYPE_DEFAULT);
	}

	function encodeTryDelegate() internal pure returns (ExecutionMode mode) {
		return encodeCustom(CALLTYPE_DELEGATE, EXECTYPE_TRY);
	}

	function encodeCustom(CallType callType, ExecType execType) internal pure returns (ExecutionMode mode) {
		return encode(callType, execType, MODE_SELECTOR_DEFAULT, MODE_PAYLOAD_DEFAULT);
	}
}
