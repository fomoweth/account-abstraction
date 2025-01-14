// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title SafeCast
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/SafeCastLib.sol

library SafeCast {
	function toUint8(uint256 x) internal pure returns (uint8) {
		if (x >= 1 << 8) revertOverflow();
		return uint8(x);
	}

	function toUint16(uint256 x) internal pure returns (uint16) {
		if (x >= 1 << 16) revertOverflow();
		return uint16(x);
	}

	function toUint24(uint256 x) internal pure returns (uint24) {
		if (x >= 1 << 24) revertOverflow();
		return uint24(x);
	}

	function toUint32(uint256 x) internal pure returns (uint32) {
		if (x >= 1 << 32) revertOverflow();
		return uint32(x);
	}

	function toUint40(uint256 x) internal pure returns (uint40) {
		if (x >= 1 << 40) revertOverflow();
		return uint40(x);
	}

	function toUint48(uint256 x) internal pure returns (uint48) {
		if (x >= 1 << 48) revertOverflow();
		return uint48(x);
	}

	function toUint56(uint256 x) internal pure returns (uint56) {
		if (x >= 1 << 56) revertOverflow();
		return uint56(x);
	}

	function toUint64(uint256 x) internal pure returns (uint64) {
		if (x >= 1 << 64) revertOverflow();
		return uint64(x);
	}

	function toUint72(uint256 x) internal pure returns (uint72) {
		if (x >= 1 << 72) revertOverflow();
		return uint72(x);
	}

	function toUint80(uint256 x) internal pure returns (uint80) {
		if (x >= 1 << 80) revertOverflow();
		return uint80(x);
	}

	function toUint88(uint256 x) internal pure returns (uint88) {
		if (x >= 1 << 88) revertOverflow();
		return uint88(x);
	}

	function toUint96(uint256 x) internal pure returns (uint96) {
		if (x >= 1 << 96) revertOverflow();
		return uint96(x);
	}

	function toUint104(uint256 x) internal pure returns (uint104) {
		if (x >= 1 << 104) revertOverflow();
		return uint104(x);
	}

	function toUint112(uint256 x) internal pure returns (uint112) {
		if (x >= 1 << 112) revertOverflow();
		return uint112(x);
	}

	function toUint120(uint256 x) internal pure returns (uint120) {
		if (x >= 1 << 120) revertOverflow();
		return uint120(x);
	}

	function toUint128(uint256 x) internal pure returns (uint128) {
		if (x >= 1 << 128) revertOverflow();
		return uint128(x);
	}

	function toUint136(uint256 x) internal pure returns (uint136) {
		if (x >= 1 << 136) revertOverflow();
		return uint136(x);
	}

	function toUint144(uint256 x) internal pure returns (uint144) {
		if (x >= 1 << 144) revertOverflow();
		return uint144(x);
	}

	function toUint152(uint256 x) internal pure returns (uint152) {
		if (x >= 1 << 152) revertOverflow();
		return uint152(x);
	}

	function toUint160(uint256 x) internal pure returns (uint160) {
		if (x >= 1 << 160) revertOverflow();
		return uint160(x);
	}

	function toUint168(uint256 x) internal pure returns (uint168) {
		if (x >= 1 << 168) revertOverflow();
		return uint168(x);
	}

	function toUint176(uint256 x) internal pure returns (uint176) {
		if (x >= 1 << 176) revertOverflow();
		return uint176(x);
	}

	function toUint184(uint256 x) internal pure returns (uint184) {
		if (x >= 1 << 184) revertOverflow();
		return uint184(x);
	}

	function toUint192(uint256 x) internal pure returns (uint192) {
		if (x >= 1 << 192) revertOverflow();
		return uint192(x);
	}

	function toUint200(uint256 x) internal pure returns (uint200) {
		if (x >= 1 << 200) revertOverflow();
		return uint200(x);
	}

	function toUint208(uint256 x) internal pure returns (uint208) {
		if (x >= 1 << 208) revertOverflow();
		return uint208(x);
	}

	function toUint216(uint256 x) internal pure returns (uint216) {
		if (x >= 1 << 216) revertOverflow();
		return uint216(x);
	}

	function toUint224(uint256 x) internal pure returns (uint224) {
		if (x >= 1 << 224) revertOverflow();
		return uint224(x);
	}

	function toUint232(uint256 x) internal pure returns (uint232) {
		if (x >= 1 << 232) revertOverflow();
		return uint232(x);
	}

	function toUint240(uint256 x) internal pure returns (uint240) {
		if (x >= 1 << 240) revertOverflow();
		return uint240(x);
	}

	function toUint248(uint256 x) internal pure returns (uint248) {
		if (x >= 1 << 248) revertOverflow();
		return uint248(x);
	}

	function toInt8(int256 x) internal pure returns (int8) {
		unchecked {
			if (((1 << 7) + uint256(x)) >> 8 == uint256(0)) return int8(x);
			revertOverflow();
		}
	}

	function toInt16(int256 x) internal pure returns (int16) {
		unchecked {
			if (((1 << 15) + uint256(x)) >> 16 == uint256(0)) return int16(x);
			revertOverflow();
		}
	}

	function toInt24(int256 x) internal pure returns (int24) {
		unchecked {
			if (((1 << 23) + uint256(x)) >> 24 == uint256(0)) return int24(x);
			revertOverflow();
		}
	}

	function toInt32(int256 x) internal pure returns (int32) {
		unchecked {
			if (((1 << 31) + uint256(x)) >> 32 == uint256(0)) return int32(x);
			revertOverflow();
		}
	}

	function toInt40(int256 x) internal pure returns (int40) {
		unchecked {
			if (((1 << 39) + uint256(x)) >> 40 == uint256(0)) return int40(x);
			revertOverflow();
		}
	}

	function toInt48(int256 x) internal pure returns (int48) {
		unchecked {
			if (((1 << 47) + uint256(x)) >> 48 == uint256(0)) return int48(x);
			revertOverflow();
		}
	}

	function toInt56(int256 x) internal pure returns (int56) {
		unchecked {
			if (((1 << 55) + uint256(x)) >> 56 == uint256(0)) return int56(x);
			revertOverflow();
		}
	}

	function toInt64(int256 x) internal pure returns (int64) {
		unchecked {
			if (((1 << 63) + uint256(x)) >> 64 == uint256(0)) return int64(x);
			revertOverflow();
		}
	}

	function toInt72(int256 x) internal pure returns (int72) {
		unchecked {
			if (((1 << 71) + uint256(x)) >> 72 == uint256(0)) return int72(x);
			revertOverflow();
		}
	}

	function toInt80(int256 x) internal pure returns (int80) {
		unchecked {
			if (((1 << 79) + uint256(x)) >> 80 == uint256(0)) return int80(x);
			revertOverflow();
		}
	}

	function toInt88(int256 x) internal pure returns (int88) {
		unchecked {
			if (((1 << 87) + uint256(x)) >> 88 == uint256(0)) return int88(x);
			revertOverflow();
		}
	}

	function toInt96(int256 x) internal pure returns (int96) {
		unchecked {
			if (((1 << 95) + uint256(x)) >> 96 == uint256(0)) return int96(x);
			revertOverflow();
		}
	}

	function toInt104(int256 x) internal pure returns (int104) {
		unchecked {
			if (((1 << 103) + uint256(x)) >> 104 == uint256(0)) return int104(x);
			revertOverflow();
		}
	}

	function toInt112(int256 x) internal pure returns (int112) {
		unchecked {
			if (((1 << 111) + uint256(x)) >> 112 == uint256(0)) return int112(x);
			revertOverflow();
		}
	}

	function toInt120(int256 x) internal pure returns (int120) {
		unchecked {
			if (((1 << 119) + uint256(x)) >> 120 == uint256(0)) return int120(x);
			revertOverflow();
		}
	}

	function toInt128(int256 x) internal pure returns (int128) {
		unchecked {
			if (((1 << 127) + uint256(x)) >> 128 == uint256(0)) return int128(x);
			revertOverflow();
		}
	}

	function toInt136(int256 x) internal pure returns (int136) {
		unchecked {
			if (((1 << 135) + uint256(x)) >> 136 == uint256(0)) return int136(x);
			revertOverflow();
		}
	}

	function toInt144(int256 x) internal pure returns (int144) {
		unchecked {
			if (((1 << 143) + uint256(x)) >> 144 == uint256(0)) return int144(x);
			revertOverflow();
		}
	}

	function toInt152(int256 x) internal pure returns (int152) {
		unchecked {
			if (((1 << 151) + uint256(x)) >> 152 == uint256(0)) return int152(x);
			revertOverflow();
		}
	}

	function toInt160(int256 x) internal pure returns (int160) {
		unchecked {
			if (((1 << 159) + uint256(x)) >> 160 == uint256(0)) return int160(x);
			revertOverflow();
		}
	}

	function toInt168(int256 x) internal pure returns (int168) {
		unchecked {
			if (((1 << 167) + uint256(x)) >> 168 == uint256(0)) return int168(x);
			revertOverflow();
		}
	}

	function toInt176(int256 x) internal pure returns (int176) {
		unchecked {
			if (((1 << 175) + uint256(x)) >> 176 == uint256(0)) return int176(x);
			revertOverflow();
		}
	}

	function toInt184(int256 x) internal pure returns (int184) {
		unchecked {
			if (((1 << 183) + uint256(x)) >> 184 == uint256(0)) return int184(x);
			revertOverflow();
		}
	}

	function toInt192(int256 x) internal pure returns (int192) {
		unchecked {
			if (((1 << 191) + uint256(x)) >> 192 == uint256(0)) return int192(x);
			revertOverflow();
		}
	}

	function toInt200(int256 x) internal pure returns (int200) {
		unchecked {
			if (((1 << 199) + uint256(x)) >> 200 == uint256(0)) return int200(x);
			revertOverflow();
		}
	}

	function toInt208(int256 x) internal pure returns (int208) {
		unchecked {
			if (((1 << 207) + uint256(x)) >> 208 == uint256(0)) return int208(x);
			revertOverflow();
		}
	}

	function toInt216(int256 x) internal pure returns (int216) {
		unchecked {
			if (((1 << 215) + uint256(x)) >> 216 == uint256(0)) return int216(x);
			revertOverflow();
		}
	}

	function toInt224(int256 x) internal pure returns (int224) {
		unchecked {
			if (((1 << 223) + uint256(x)) >> 224 == uint256(0)) return int224(x);
			revertOverflow();
		}
	}

	function toInt232(int256 x) internal pure returns (int232) {
		unchecked {
			if (((1 << 231) + uint256(x)) >> 232 == uint256(0)) return int232(x);
			revertOverflow();
		}
	}

	function toInt240(int256 x) internal pure returns (int240) {
		unchecked {
			if (((1 << 239) + uint256(x)) >> 240 == uint256(0)) return int240(x);
			revertOverflow();
		}
	}

	function toInt248(int256 x) internal pure returns (int248) {
		unchecked {
			if (((1 << 247) + uint256(x)) >> 248 == uint256(0)) return int248(x);
			revertOverflow();
		}
	}

	function toInt8(uint256 x) internal pure returns (int8) {
		if (x >= 1 << 7) revertOverflow();
		return int8(int256(x));
	}

	function toInt16(uint256 x) internal pure returns (int16) {
		if (x >= 1 << 15) revertOverflow();
		return int16(int256(x));
	}

	function toInt24(uint256 x) internal pure returns (int24) {
		if (x >= 1 << 23) revertOverflow();
		return int24(int256(x));
	}

	function toInt32(uint256 x) internal pure returns (int32) {
		if (x >= 1 << 31) revertOverflow();
		return int32(int256(x));
	}

	function toInt40(uint256 x) internal pure returns (int40) {
		if (x >= 1 << 39) revertOverflow();
		return int40(int256(x));
	}

	function toInt48(uint256 x) internal pure returns (int48) {
		if (x >= 1 << 47) revertOverflow();
		return int48(int256(x));
	}

	function toInt56(uint256 x) internal pure returns (int56) {
		if (x >= 1 << 55) revertOverflow();
		return int56(int256(x));
	}

	function toInt64(uint256 x) internal pure returns (int64) {
		if (x >= 1 << 63) revertOverflow();
		return int64(int256(x));
	}

	function toInt72(uint256 x) internal pure returns (int72) {
		if (x >= 1 << 71) revertOverflow();
		return int72(int256(x));
	}

	function toInt80(uint256 x) internal pure returns (int80) {
		if (x >= 1 << 79) revertOverflow();
		return int80(int256(x));
	}

	function toInt88(uint256 x) internal pure returns (int88) {
		if (x >= 1 << 87) revertOverflow();
		return int88(int256(x));
	}

	function toInt96(uint256 x) internal pure returns (int96) {
		if (x >= 1 << 95) revertOverflow();
		return int96(int256(x));
	}

	function toInt104(uint256 x) internal pure returns (int104) {
		if (x >= 1 << 103) revertOverflow();
		return int104(int256(x));
	}

	function toInt112(uint256 x) internal pure returns (int112) {
		if (x >= 1 << 111) revertOverflow();
		return int112(int256(x));
	}

	function toInt120(uint256 x) internal pure returns (int120) {
		if (x >= 1 << 119) revertOverflow();
		return int120(int256(x));
	}

	function toInt128(uint256 x) internal pure returns (int128) {
		if (x >= 1 << 127) revertOverflow();
		return int128(int256(x));
	}

	function toInt136(uint256 x) internal pure returns (int136) {
		if (x >= 1 << 135) revertOverflow();
		return int136(int256(x));
	}

	function toInt144(uint256 x) internal pure returns (int144) {
		if (x >= 1 << 143) revertOverflow();
		return int144(int256(x));
	}

	function toInt152(uint256 x) internal pure returns (int152) {
		if (x >= 1 << 151) revertOverflow();
		return int152(int256(x));
	}

	function toInt160(uint256 x) internal pure returns (int160) {
		if (x >= 1 << 159) revertOverflow();
		return int160(int256(x));
	}

	function toInt168(uint256 x) internal pure returns (int168) {
		if (x >= 1 << 167) revertOverflow();
		return int168(int256(x));
	}

	function toInt176(uint256 x) internal pure returns (int176) {
		if (x >= 1 << 175) revertOverflow();
		return int176(int256(x));
	}

	function toInt184(uint256 x) internal pure returns (int184) {
		if (x >= 1 << 183) revertOverflow();
		return int184(int256(x));
	}

	function toInt192(uint256 x) internal pure returns (int192) {
		if (x >= 1 << 191) revertOverflow();
		return int192(int256(x));
	}

	function toInt200(uint256 x) internal pure returns (int200) {
		if (x >= 1 << 199) revertOverflow();
		return int200(int256(x));
	}

	function toInt208(uint256 x) internal pure returns (int208) {
		if (x >= 1 << 207) revertOverflow();
		return int208(int256(x));
	}

	function toInt216(uint256 x) internal pure returns (int216) {
		if (x >= 1 << 215) revertOverflow();
		return int216(int256(x));
	}

	function toInt224(uint256 x) internal pure returns (int224) {
		if (x >= 1 << 223) revertOverflow();
		return int224(int256(x));
	}

	function toInt232(uint256 x) internal pure returns (int232) {
		if (x >= 1 << 231) revertOverflow();
		return int232(int256(x));
	}

	function toInt240(uint256 x) internal pure returns (int240) {
		if (x >= 1 << 239) revertOverflow();
		return int240(int256(x));
	}

	function toInt248(uint256 x) internal pure returns (int248) {
		if (x >= 1 << 247) revertOverflow();
		return int248(int256(x));
	}

	function toInt256(uint256 x) internal pure returns (int256) {
		if (int256(x) >= 0) return int256(x);
		revertOverflow();
	}

	function toUint256(int256 x) internal pure returns (uint256) {
		if (x >= 0) return uint256(x);
		revertOverflow();
	}

	function toUint(bool x) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := iszero(iszero(x))
		}
	}

	function toBool(uint256 x) internal pure returns (bool z) {
		assembly ("memory-safe") {
			z := iszero(iszero(x))
		}
	}

	function revertOverflow() private pure {
		assembly ("memory-safe") {
			mstore(0x00, 0x93dafdf1) // SafeCastOverflow()
			revert(0x1c, 0x04)
		}
	}
}
