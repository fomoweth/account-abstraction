// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {ExecutionModeLib, ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {Vortex} from "src/Vortex.sol";

library ExecutionUtils {
	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);
	CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);
	CallType internal constant CALLTYPE_STATIC = CallType.wrap(0xFE);
	CallType internal constant CALLTYPE_DELEGATE = CallType.wrap(0xFF);

	ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);
	ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

	function encodeExecutionCalldata(
		ExecType execType,
		address target,
		uint256 value,
		bytes memory callData
	) internal pure returns (bytes memory) {
		vm.assertTrue(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(CALLTYPE_SINGLE, execType);
		bytes memory executionCalldata = abi.encodePacked(target, value, callData);

		return abi.encodeCall(Vortex.execute, (mode, executionCalldata));
	}

	function encodeExecutionCalldata(
		ExecType execType,
		Execution[] memory executions
	) internal pure returns (bytes memory) {
		vm.assertTrue(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(CALLTYPE_BATCH, execType);
		bytes memory executionCalldata = abi.encode(executions);

		return abi.encodeCall(Vortex.execute, (mode, executionCalldata));
	}

	function encodeExecutionCalldata(
		ExecType execType,
		address target,
		bytes memory callData
	) internal pure returns (bytes memory) {
		vm.assertTrue(execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY);

		ExecutionMode mode = ExecutionModeLib.encodeCustom(CALLTYPE_DELEGATE, execType);
		bytes memory executionCalldata = abi.encodePacked(target, callData);

		return abi.encodeCall(Vortex.execute, (mode, executionCalldata));
	}

	function arrayify(Execution memory execution) internal pure returns (Execution[] memory executions) {
		executions = new Execution[](1);
		executions[0] = execution;
	}
}
