// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/ModuleType.sol";

library SolArray {
	function moduleTypes(ModuleType a) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](1);
		arr[0] = a;
	}

	function moduleTypes(ModuleType a, ModuleType b) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function moduleTypes(ModuleType a, ModuleType b, ModuleType c) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function moduleTypes(
		ModuleType a,
		ModuleType b,
		ModuleType c,
		ModuleType d
	) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function moduleTypes(
		ModuleType a,
		ModuleType b,
		ModuleType c,
		ModuleType d,
		ModuleType e
	) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function moduleTypes(
		ModuleType a,
		ModuleType b,
		ModuleType c,
		ModuleType d,
		ModuleType e,
		ModuleType f
	) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function moduleTypes(
		ModuleType a,
		ModuleType b,
		ModuleType c,
		ModuleType d,
		ModuleType e,
		ModuleType f,
		ModuleType g
	) internal pure returns (ModuleType[] memory arr) {
		arr = new ModuleType[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint8s(uint8 a) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](1);
		arr[0] = a;
	}

	function uint8s(uint8 a, uint8 b) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint8s(uint8 a, uint8 b, uint8 c) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint8s(uint8 a, uint8 b, uint8 c, uint8 d) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint8s(uint8 a, uint8 b, uint8 c, uint8 d, uint8 e) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint8s(uint8 a, uint8 b, uint8 c, uint8 d, uint8 e, uint8 f) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint8s(
		uint8 a,
		uint8 b,
		uint8 c,
		uint8 d,
		uint8 e,
		uint8 f,
		uint8 g
	) internal pure returns (uint8[] memory arr) {
		arr = new uint8[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint16s(uint16 a) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](1);
		arr[0] = a;
	}

	function uint16s(uint16 a, uint16 b) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint16s(uint16 a, uint16 b, uint16 c) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint16s(uint16 a, uint16 b, uint16 c, uint16 d) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint16s(uint16 a, uint16 b, uint16 c, uint16 d, uint16 e) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint16s(
		uint16 a,
		uint16 b,
		uint16 c,
		uint16 d,
		uint16 e,
		uint16 f
	) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint16s(
		uint16 a,
		uint16 b,
		uint16 c,
		uint16 d,
		uint16 e,
		uint16 f,
		uint16 g
	) internal pure returns (uint16[] memory arr) {
		arr = new uint16[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint32s(uint32 a) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](1);
		arr[0] = a;
	}

	function uint32s(uint32 a, uint32 b) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint32s(uint32 a, uint32 b, uint32 c) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint32s(uint32 a, uint32 b, uint32 c, uint32 d) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint32s(uint32 a, uint32 b, uint32 c, uint32 d, uint32 e) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint32s(
		uint32 a,
		uint32 b,
		uint32 c,
		uint32 d,
		uint32 e,
		uint32 f
	) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint32s(
		uint32 a,
		uint32 b,
		uint32 c,
		uint32 d,
		uint32 e,
		uint32 f,
		uint32 g
	) internal pure returns (uint32[] memory arr) {
		arr = new uint32[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint24s(uint24 a) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](1);
		arr[0] = a;
	}

	function uint24s(uint24 a, uint24 b) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint24s(uint24 a, uint24 b, uint24 c) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint24s(uint24 a, uint24 b, uint24 c, uint24 d) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint24s(uint24 a, uint24 b, uint24 c, uint24 d, uint24 e) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint24s(
		uint24 a,
		uint24 b,
		uint24 c,
		uint24 d,
		uint24 e,
		uint24 f
	) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint24s(
		uint24 a,
		uint24 b,
		uint24 c,
		uint24 d,
		uint24 e,
		uint24 f,
		uint24 g
	) internal pure returns (uint24[] memory arr) {
		arr = new uint24[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint40s(uint40 a) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](1);
		arr[0] = a;
	}

	function uint40s(uint40 a, uint40 b) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint40s(uint40 a, uint40 b, uint40 c) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint40s(uint40 a, uint40 b, uint40 c, uint40 d) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint40s(uint40 a, uint40 b, uint40 c, uint40 d, uint40 e) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint40s(
		uint40 a,
		uint40 b,
		uint40 c,
		uint40 d,
		uint40 e,
		uint40 f
	) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint40s(
		uint40 a,
		uint40 b,
		uint40 c,
		uint40 d,
		uint40 e,
		uint40 f,
		uint40 g
	) internal pure returns (uint40[] memory arr) {
		arr = new uint40[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint64s(uint64 a) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](1);
		arr[0] = a;
	}

	function uint64s(uint64 a, uint64 b) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint64s(uint64 a, uint64 b, uint64 c) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint64s(uint64 a, uint64 b, uint64 c, uint64 d) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint64s(uint64 a, uint64 b, uint64 c, uint64 d, uint64 e) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint64s(
		uint64 a,
		uint64 b,
		uint64 c,
		uint64 d,
		uint64 e,
		uint64 f
	) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint64s(
		uint64 a,
		uint64 b,
		uint64 c,
		uint64 d,
		uint64 e,
		uint64 f,
		uint64 g
	) internal pure returns (uint64[] memory arr) {
		arr = new uint64[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint128s(uint128 a) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](1);
		arr[0] = a;
	}

	function uint128s(uint128 a, uint128 b) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint128s(uint128 a, uint128 b, uint128 c) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint128s(uint128 a, uint128 b, uint128 c, uint128 d) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint128s(
		uint128 a,
		uint128 b,
		uint128 c,
		uint128 d,
		uint128 e
	) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint128s(
		uint128 a,
		uint128 b,
		uint128 c,
		uint128 d,
		uint128 e,
		uint128 f
	) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint128s(
		uint128 a,
		uint128 b,
		uint128 c,
		uint128 d,
		uint128 e,
		uint128 f,
		uint128 g
	) internal pure returns (uint128[] memory arr) {
		arr = new uint128[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function uint256s(uint256 a) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](1);
		arr[0] = a;
	}

	function uint256s(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function uint256s(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function uint256s(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function uint256s(
		uint256 a,
		uint256 b,
		uint256 c,
		uint256 d,
		uint256 e
	) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function uint256s(
		uint256 a,
		uint256 b,
		uint256 c,
		uint256 d,
		uint256 e,
		uint256 f
	) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function uint256s(
		uint256 a,
		uint256 b,
		uint256 c,
		uint256 d,
		uint256 e,
		uint256 f,
		uint256 g
	) internal pure returns (uint256[] memory arr) {
		arr = new uint256[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int8s(int8 a) internal pure returns (int8[] memory arr) {
		arr = new int8[](1);
		arr[0] = a;
	}

	function int8s(int8 a, int8 b) internal pure returns (int8[] memory arr) {
		arr = new int8[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int8s(int8 a, int8 b, int8 c) internal pure returns (int8[] memory arr) {
		arr = new int8[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int8s(int8 a, int8 b, int8 c, int8 d) internal pure returns (int8[] memory arr) {
		arr = new int8[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int8s(int8 a, int8 b, int8 c, int8 d, int8 e) internal pure returns (int8[] memory arr) {
		arr = new int8[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int8s(int8 a, int8 b, int8 c, int8 d, int8 e, int8 f) internal pure returns (int8[] memory arr) {
		arr = new int8[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int8s(int8 a, int8 b, int8 c, int8 d, int8 e, int8 f, int8 g) internal pure returns (int8[] memory arr) {
		arr = new int8[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int16s(int16 a) internal pure returns (int16[] memory arr) {
		arr = new int16[](1);
		arr[0] = a;
	}

	function int16s(int16 a, int16 b) internal pure returns (int16[] memory arr) {
		arr = new int16[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int16s(int16 a, int16 b, int16 c) internal pure returns (int16[] memory arr) {
		arr = new int16[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int16s(int16 a, int16 b, int16 c, int16 d) internal pure returns (int16[] memory arr) {
		arr = new int16[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int16s(int16 a, int16 b, int16 c, int16 d, int16 e) internal pure returns (int16[] memory arr) {
		arr = new int16[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int16s(int16 a, int16 b, int16 c, int16 d, int16 e, int16 f) internal pure returns (int16[] memory arr) {
		arr = new int16[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int16s(
		int16 a,
		int16 b,
		int16 c,
		int16 d,
		int16 e,
		int16 f,
		int16 g
	) internal pure returns (int16[] memory arr) {
		arr = new int16[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int32s(int32 a) internal pure returns (int32[] memory arr) {
		arr = new int32[](1);
		arr[0] = a;
	}

	function int32s(int32 a, int32 b) internal pure returns (int32[] memory arr) {
		arr = new int32[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int32s(int32 a, int32 b, int32 c) internal pure returns (int32[] memory arr) {
		arr = new int32[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int32s(int32 a, int32 b, int32 c, int32 d) internal pure returns (int32[] memory arr) {
		arr = new int32[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int32s(int32 a, int32 b, int32 c, int32 d, int32 e) internal pure returns (int32[] memory arr) {
		arr = new int32[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int32s(int32 a, int32 b, int32 c, int32 d, int32 e, int32 f) internal pure returns (int32[] memory arr) {
		arr = new int32[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int32s(
		int32 a,
		int32 b,
		int32 c,
		int32 d,
		int32 e,
		int32 f,
		int32 g
	) internal pure returns (int32[] memory arr) {
		arr = new int32[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int64s(int64 a) internal pure returns (int64[] memory arr) {
		arr = new int64[](1);
		arr[0] = a;
	}

	function int64s(int64 a, int64 b) internal pure returns (int64[] memory arr) {
		arr = new int64[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int64s(int64 a, int64 b, int64 c) internal pure returns (int64[] memory arr) {
		arr = new int64[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int64s(int64 a, int64 b, int64 c, int64 d) internal pure returns (int64[] memory arr) {
		arr = new int64[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int64s(int64 a, int64 b, int64 c, int64 d, int64 e) internal pure returns (int64[] memory arr) {
		arr = new int64[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int64s(int64 a, int64 b, int64 c, int64 d, int64 e, int64 f) internal pure returns (int64[] memory arr) {
		arr = new int64[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int64s(
		int64 a,
		int64 b,
		int64 c,
		int64 d,
		int64 e,
		int64 f,
		int64 g
	) internal pure returns (int64[] memory arr) {
		arr = new int64[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int128s(int128 a) internal pure returns (int128[] memory arr) {
		arr = new int128[](1);
		arr[0] = a;
	}

	function int128s(int128 a, int128 b) internal pure returns (int128[] memory arr) {
		arr = new int128[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int128s(int128 a, int128 b, int128 c) internal pure returns (int128[] memory arr) {
		arr = new int128[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int128s(int128 a, int128 b, int128 c, int128 d) internal pure returns (int128[] memory arr) {
		arr = new int128[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int128s(int128 a, int128 b, int128 c, int128 d, int128 e) internal pure returns (int128[] memory arr) {
		arr = new int128[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int128s(
		int128 a,
		int128 b,
		int128 c,
		int128 d,
		int128 e,
		int128 f
	) internal pure returns (int128[] memory arr) {
		arr = new int128[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int128s(
		int128 a,
		int128 b,
		int128 c,
		int128 d,
		int128 e,
		int128 f,
		int128 g
	) internal pure returns (int128[] memory arr) {
		arr = new int128[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function int256s(int256 a) internal pure returns (int256[] memory arr) {
		arr = new int256[](1);
		arr[0] = a;
	}

	function int256s(int256 a, int256 b) internal pure returns (int256[] memory arr) {
		arr = new int256[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function int256s(int256 a, int256 b, int256 c) internal pure returns (int256[] memory arr) {
		arr = new int256[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function int256s(int256 a, int256 b, int256 c, int256 d) internal pure returns (int256[] memory arr) {
		arr = new int256[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function int256s(int256 a, int256 b, int256 c, int256 d, int256 e) internal pure returns (int256[] memory arr) {
		arr = new int256[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function int256s(
		int256 a,
		int256 b,
		int256 c,
		int256 d,
		int256 e,
		int256 f
	) internal pure returns (int256[] memory arr) {
		arr = new int256[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function int256s(
		int256 a,
		int256 b,
		int256 c,
		int256 d,
		int256 e,
		int256 f,
		int256 g
	) internal pure returns (int256[] memory arr) {
		arr = new int256[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes1s(bytes1 a) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](1);
		arr[0] = a;
	}

	function bytes1s(bytes1 a, bytes1 b) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes1s(bytes1 a, bytes1 b, bytes1 c) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes1s(bytes1 a, bytes1 b, bytes1 c, bytes1 d) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes1s(bytes1 a, bytes1 b, bytes1 c, bytes1 d, bytes1 e) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes1s(
		bytes1 a,
		bytes1 b,
		bytes1 c,
		bytes1 d,
		bytes1 e,
		bytes1 f
	) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes1s(
		bytes1 a,
		bytes1 b,
		bytes1 c,
		bytes1 d,
		bytes1 e,
		bytes1 f,
		bytes1 g
	) internal pure returns (bytes1[] memory arr) {
		arr = new bytes1[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes4s(bytes4 a) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](1);
		arr[0] = a;
	}

	function bytes4s(bytes4 a, bytes4 b) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes4s(bytes4 a, bytes4 b, bytes4 c) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes4s(bytes4 a, bytes4 b, bytes4 c, bytes4 d) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes4s(bytes4 a, bytes4 b, bytes4 c, bytes4 d, bytes4 e) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes4s(
		bytes4 a,
		bytes4 b,
		bytes4 c,
		bytes4 d,
		bytes4 e,
		bytes4 f
	) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes4s(
		bytes4 a,
		bytes4 b,
		bytes4 c,
		bytes4 d,
		bytes4 e,
		bytes4 f,
		bytes4 g
	) internal pure returns (bytes4[] memory arr) {
		arr = new bytes4[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes8s(bytes8 a) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](1);
		arr[0] = a;
	}

	function bytes8s(bytes8 a, bytes8 b) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes8s(bytes8 a, bytes8 b, bytes8 c) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes8s(bytes8 a, bytes8 b, bytes8 c, bytes8 d) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes8s(bytes8 a, bytes8 b, bytes8 c, bytes8 d, bytes8 e) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes8s(
		bytes8 a,
		bytes8 b,
		bytes8 c,
		bytes8 d,
		bytes8 e,
		bytes8 f
	) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes8s(
		bytes8 a,
		bytes8 b,
		bytes8 c,
		bytes8 d,
		bytes8 e,
		bytes8 f,
		bytes8 g
	) internal pure returns (bytes8[] memory arr) {
		arr = new bytes8[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes16s(bytes16 a) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](1);
		arr[0] = a;
	}

	function bytes16s(bytes16 a, bytes16 b) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes16s(bytes16 a, bytes16 b, bytes16 c) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes16s(bytes16 a, bytes16 b, bytes16 c, bytes16 d) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes16s(
		bytes16 a,
		bytes16 b,
		bytes16 c,
		bytes16 d,
		bytes16 e
	) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes16s(
		bytes16 a,
		bytes16 b,
		bytes16 c,
		bytes16 d,
		bytes16 e,
		bytes16 f
	) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes16s(
		bytes16 a,
		bytes16 b,
		bytes16 c,
		bytes16 d,
		bytes16 e,
		bytes16 f,
		bytes16 g
	) internal pure returns (bytes16[] memory arr) {
		arr = new bytes16[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes20s(bytes20 a) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](1);
		arr[0] = a;
	}

	function bytes20s(bytes20 a, bytes20 b) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes20s(bytes20 a, bytes20 b, bytes20 c) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes20s(bytes20 a, bytes20 b, bytes20 c, bytes20 d) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes20s(
		bytes20 a,
		bytes20 b,
		bytes20 c,
		bytes20 d,
		bytes20 e
	) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes20s(
		bytes20 a,
		bytes20 b,
		bytes20 c,
		bytes20 d,
		bytes20 e,
		bytes20 f
	) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes20s(
		bytes20 a,
		bytes20 b,
		bytes20 c,
		bytes20 d,
		bytes20 e,
		bytes20 f,
		bytes20 g
	) internal pure returns (bytes20[] memory arr) {
		arr = new bytes20[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytes32s(bytes32 a) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](1);
		arr[0] = a;
	}

	function bytes32s(bytes32 a, bytes32 b) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytes32s(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytes32s(bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytes32s(
		bytes32 a,
		bytes32 b,
		bytes32 c,
		bytes32 d,
		bytes32 e
	) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytes32s(
		bytes32 a,
		bytes32 b,
		bytes32 c,
		bytes32 d,
		bytes32 e,
		bytes32 f
	) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytes32s(
		bytes32 a,
		bytes32 b,
		bytes32 c,
		bytes32 d,
		bytes32 e,
		bytes32 f,
		bytes32 g
	) internal pure returns (bytes32[] memory arr) {
		arr = new bytes32[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bytess(bytes memory a) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](1);
		arr[0] = a;
	}

	function bytess(bytes memory a, bytes memory b) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bytess(bytes memory a, bytes memory b, bytes memory c) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bytess(
		bytes memory a,
		bytes memory b,
		bytes memory c,
		bytes memory d
	) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bytess(
		bytes memory a,
		bytes memory b,
		bytes memory c,
		bytes memory d,
		bytes memory e
	) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bytess(
		bytes memory a,
		bytes memory b,
		bytes memory c,
		bytes memory d,
		bytes memory e,
		bytes memory f
	) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bytess(
		bytes memory a,
		bytes memory b,
		bytes memory c,
		bytes memory d,
		bytes memory e,
		bytes memory f,
		bytes memory g
	) internal pure returns (bytes[] memory arr) {
		arr = new bytes[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function addresses(address a) internal pure returns (address[] memory arr) {
		arr = new address[](1);
		arr[0] = a;
	}

	function addresses(address a, address b) internal pure returns (address[] memory arr) {
		arr = new address[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function addresses(address a, address b, address c) internal pure returns (address[] memory arr) {
		arr = new address[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function addresses(address a, address b, address c, address d) internal pure returns (address[] memory arr) {
		arr = new address[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function addresses(
		address a,
		address b,
		address c,
		address d,
		address e
	) internal pure returns (address[] memory arr) {
		arr = new address[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function addresses(
		address a,
		address b,
		address c,
		address d,
		address e,
		address f
	) internal pure returns (address[] memory arr) {
		arr = new address[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function addresses(
		address a,
		address b,
		address c,
		address d,
		address e,
		address f,
		address g
	) internal pure returns (address[] memory arr) {
		arr = new address[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function currencies(Currency a) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](1);
		arr[0] = a;
	}

	function currencies(Currency a, Currency b) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function currencies(Currency a, Currency b, Currency c) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function currencies(Currency a, Currency b, Currency c, Currency d) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function currencies(
		Currency a,
		Currency b,
		Currency c,
		Currency d,
		Currency e
	) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function currencies(
		Currency a,
		Currency b,
		Currency c,
		Currency d,
		Currency e,
		Currency f
	) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function currencies(
		Currency a,
		Currency b,
		Currency c,
		Currency d,
		Currency e,
		Currency f,
		Currency g
	) internal pure returns (Currency[] memory arr) {
		arr = new Currency[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function bools(bool a) internal pure returns (bool[] memory arr) {
		arr = new bool[](1);
		arr[0] = a;
	}

	function bools(bool a, bool b) internal pure returns (bool[] memory arr) {
		arr = new bool[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function bools(bool a, bool b, bool c) internal pure returns (bool[] memory arr) {
		arr = new bool[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function bools(bool a, bool b, bool c, bool d) internal pure returns (bool[] memory arr) {
		arr = new bool[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function bools(bool a, bool b, bool c, bool d, bool e) internal pure returns (bool[] memory arr) {
		arr = new bool[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function bools(bool a, bool b, bool c, bool d, bool e, bool f) internal pure returns (bool[] memory arr) {
		arr = new bool[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function bools(bool a, bool b, bool c, bool d, bool e, bool f, bool g) internal pure returns (bool[] memory arr) {
		arr = new bool[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}

	function strings(string memory a) internal pure returns (string[] memory arr) {
		arr = new string[](1);
		arr[0] = a;
	}

	function strings(string memory a, string memory b) internal pure returns (string[] memory arr) {
		arr = new string[](2);
		arr[0] = a;
		arr[1] = b;
	}

	function strings(string memory a, string memory b, string memory c) internal pure returns (string[] memory arr) {
		arr = new string[](3);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
	}

	function strings(
		string memory a,
		string memory b,
		string memory c,
		string memory d
	) internal pure returns (string[] memory arr) {
		arr = new string[](4);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
	}

	function strings(
		string memory a,
		string memory b,
		string memory c,
		string memory d,
		string memory e
	) internal pure returns (string[] memory arr) {
		arr = new string[](5);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
	}

	function strings(
		string memory a,
		string memory b,
		string memory c,
		string memory d,
		string memory e,
		string memory f
	) internal pure returns (string[] memory arr) {
		arr = new string[](6);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
	}

	function strings(
		string memory a,
		string memory b,
		string memory c,
		string memory d,
		string memory e,
		string memory f,
		string memory g
	) internal pure returns (string[] memory arr) {
		arr = new string[](7);
		arr[0] = a;
		arr[1] = b;
		arr[2] = c;
		arr[3] = d;
		arr[4] = e;
		arr[5] = f;
		arr[6] = g;
	}
}
