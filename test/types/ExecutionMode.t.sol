// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType, ModeSelector, ModePayload} from "src/types/ExecutionMode.sol";
import {Constants} from "test/shared/env/Constants.sol";

contract ExecutionModeTest is Test, Constants {
	function setUp() public virtual {}

	function test_parseTypes() public virtual {
		ExecutionMode mode;
		CallType callType;
		ExecType execType;

		mode = ExecutionModeLib.encodeSingle();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_SINGLE);
		assertTrue(execType == EXECTYPE_DEFAULT);

		mode = ExecutionModeLib.encodeTrySingle();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_SINGLE);
		assertTrue(execType == EXECTYPE_TRY);

		mode = ExecutionModeLib.encodeBatch();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_BATCH);
		assertTrue(execType == EXECTYPE_DEFAULT);

		mode = ExecutionModeLib.encodeTryBatch();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_BATCH);
		assertTrue(execType == EXECTYPE_TRY);

		mode = ExecutionModeLib.encodeDelegate();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_DELEGATE);
		assertTrue(execType == EXECTYPE_DEFAULT);

		mode = ExecutionModeLib.encodeTryDelegate();
		(callType, execType) = mode.parseTypes();

		assertTrue(callType == CALLTYPE_DELEGATE);
		assertTrue(execType == EXECTYPE_TRY);

		mode = ExecutionModeLib.encodeCustom(CALLTYPE_STATIC, EXECTYPE_DEFAULT);

		vm.expectRevert(abi.encodeWithSelector(0xb96fcfe4, CALLTYPE_STATIC));
		mode.parseTypes();

		mode = ExecutionModeLib.encodeCustom(CALLTYPE_SINGLE, ExecType.wrap(0x02));

		vm.expectRevert(abi.encodeWithSelector(0x1187dc06, bytes1(0x02)));
		mode.parseTypes();
	}

	function test_encode() public virtual {
		ModeSelector modeSelector = ModeSelector.wrap(vm.randomBytes4());
		ModePayload modePayload = ModePayload.wrap(bytes22(vm.randomBytes(22)));

		ExecutionMode mode = ExecutionModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, modeSelector, modePayload);
		(CallType callType, ExecType execType, ModeSelector selector, ModePayload payload) = mode.decode();

		assertTrue(callType == CALLTYPE_BATCH);
		assertTrue(execType == EXECTYPE_TRY);
		assertTrue(selector == modeSelector);
		assertTrue(payload == modePayload);
	}

	function test_encodeSingle() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeSingle();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_SINGLE);
		assertTrue(execType == EXECTYPE_DEFAULT);
	}

	function test_encodeTrySingle() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeTrySingle();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_SINGLE);
		assertTrue(execType == EXECTYPE_TRY);
	}

	function test_encodeBatch() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeBatch();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_BATCH);
		assertTrue(execType == EXECTYPE_DEFAULT);
	}

	function test_encodeTryBatch() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeTryBatch();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_BATCH);
		assertTrue(execType == EXECTYPE_TRY);
	}

	function test_encodeDelegate() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeDelegate();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_DELEGATE);
		assertTrue(execType == EXECTYPE_DEFAULT);
	}

	function test_encodeTryDelegate() public virtual {
		ExecutionMode mode = ExecutionModeLib.encodeTryDelegate();
		(CallType callType, ExecType execType, , ) = mode.decode();

		assertTrue(callType == CALLTYPE_DELEGATE);
		assertTrue(execType == EXECTYPE_TRY);
	}
}
