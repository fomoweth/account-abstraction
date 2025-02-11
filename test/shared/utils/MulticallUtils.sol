// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

IMulticall3 constant MULTICALL3 = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

library MulticallUtils {
	function aggregate(IMulticall3.Call[] memory calls) internal returns (bytes[] memory results) {
		(, results) = MULTICALL3.aggregate(calls);
	}

	function aggregate(IMulticall3.Call3[] memory calls) internal returns (bytes[] memory results) {
		IMulticall3.Result[] memory callResults = MULTICALL3.aggregate3(calls);

		uint256 length = callResults.length;
		results = new bytes[](length);

		for (uint256 i; i < length; ++i) {
			results[i] = callResults[i].returnData;
		}
	}

	function aggregate(IMulticall3.Call3Value[] memory calls) internal returns (bytes[] memory results) {
		IMulticall3.Result[] memory callResults = MULTICALL3.aggregate3Value(calls);

		uint256 length = callResults.length;
		results = new bytes[](length);

		for (uint256 i; i < length; ++i) {
			results[i] = callResults[i].returnData;
		}
	}

	function build(address target, bytes memory payload) internal pure returns (IMulticall3.Call memory call) {
		call = IMulticall3.Call({target: target, callData: payload});
	}

	function build(
		address target,
		bytes memory payload,
		bool allowFailure
	) internal pure returns (IMulticall3.Call3 memory call) {
		call = IMulticall3.Call3({target: target, callData: payload, allowFailure: allowFailure});
	}

	function build(
		address target,
		bytes memory payload,
		uint256 value,
		bool allowFailure
	) internal pure returns (IMulticall3.Call3Value memory call) {
		call = IMulticall3.Call3Value({target: target, callData: payload, allowFailure: allowFailure, value: value});
	}

	function build(address target, bytes[] memory payloads) internal pure returns (IMulticall3.Call[] memory calls) {
		uint256 length = payloads.length;
		calls = new IMulticall3.Call[](length);

		for (uint256 i; i < length; ++i) {
			calls[i] = build(target, payloads[i]);
		}
	}

	function build(
		address[] memory targets,
		bytes memory payload
	) internal pure returns (IMulticall3.Call[] memory calls) {
		uint256 length = targets.length;

		calls = new IMulticall3.Call[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payload);
		}
	}

	function build(
		address[] memory targets,
		bytes[] memory payloads
	) internal pure returns (IMulticall3.Call[] memory calls) {
		uint256 length = targets.length;
		require(length == payloads.length);

		calls = new IMulticall3.Call[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payloads[i]);
		}
	}

	function build(
		address target,
		bytes[] memory payloads,
		bool flag
	) internal pure returns (IMulticall3.Call3[] memory calls) {
		uint256 length = payloads.length;

		calls = new IMulticall3.Call3[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(target, payloads[i], flag);
		}
	}

	function build(
		address[] memory targets,
		bytes memory payload,
		bool flag
	) internal pure returns (IMulticall3.Call3[] memory calls) {
		uint256 length = targets.length;

		calls = new IMulticall3.Call3[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payload, flag);
		}
	}

	function build(
		address[] memory targets,
		bytes[] memory payloads,
		bool[] memory flags
	) internal pure returns (IMulticall3.Call3[] memory calls) {
		uint256 length = targets.length;
		require(length == payloads.length && length == flags.length);

		calls = new IMulticall3.Call3[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payloads[i], flags[i]);
		}
	}

	function build(
		address target,
		bytes[] memory payloads,
		uint256[] memory values,
		bool flag
	) internal pure returns (IMulticall3.Call3Value[] memory calls) {
		uint256 length = payloads.length;
		require(length == values.length);

		calls = new IMulticall3.Call3Value[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(target, payloads[i], values[i], flag);
		}
	}

	function build(
		address[] memory targets,
		bytes memory payload,
		uint256[] memory values,
		bool flag
	) internal pure returns (IMulticall3.Call3Value[] memory calls) {
		uint256 length = targets.length;
		require(length == values.length);

		calls = new IMulticall3.Call3Value[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payload, values[i], flag);
		}
	}

	function build(
		address[] memory targets,
		bytes[] memory payloads,
		uint256[] memory values,
		bool[] memory flags
	) internal pure returns (IMulticall3.Call3Value[] memory calls) {
		uint256 length = targets.length;
		require(length == payloads.length && length == values.length && length == flags.length);

		calls = new IMulticall3.Call3Value[](length);
		for (uint256 i; i < length; ++i) {
			calls[i] = build(targets[i], payloads[i], values[i], flags[i]);
		}
	}
}
