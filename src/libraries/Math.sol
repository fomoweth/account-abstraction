// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Math
/// @notice Provides functions to perform math operations.
library Math {
	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;

	function isEven(uint256 x) internal pure returns (bool b) {
		assembly ("memory-safe") {
			b := iszero(and(x, 1))
		}
	}

	function average(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := add(and(x, y), shr(1, xor(x, y)))
		}
	}

	function ternary(bool condition, uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
		}
	}

	function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := xor(y, mul(xor(x, y), gt(x, y)))
		}
	}

	function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := xor(y, mul(xor(x, y), lt(x, y)))
		}
	}

	function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := add(div(x, y), gt(mod(x, y), 0))
		}
	}

	function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			let mm := mulmod(x, y, not(0))
			let p0 := mul(x, y)
			let p1 := sub(sub(mm, p0), lt(mm, p0))

			if iszero(gt(d, p1)) {
				invalid()
			}

			switch iszero(p1)
			case 0 {
				let r := mulmod(x, y, d)
				p1 := sub(p1, gt(r, p0))
				p0 := sub(p0, r)

				let t := and(d, sub(0, d))
				d := div(d, t)

				let inv := xor(2, mul(3, d))
				inv := mul(inv, sub(2, mul(d, inv)))
				inv := mul(inv, sub(2, mul(d, inv)))
				inv := mul(inv, sub(2, mul(d, inv)))
				inv := mul(inv, sub(2, mul(d, inv)))
				inv := mul(inv, sub(2, mul(d, inv)))
				inv := mul(inv, sub(2, mul(d, inv)))

				z := mul(or(mul(p1, add(div(sub(0, t), t), 1)), div(p0, t)), inv)
			}
			default {
				z := div(p0, d)
			}
		}
	}

	function mulDivRoundingUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
		z = mulDiv(x, y, denominator);

		assembly ("memory-safe") {
			if mulmod(x, y, denominator) {
				z := add(z, 1)

				if iszero(z) {
					mstore(0x00, 0x35278d12) // Overflow()
					revert(0x1c, 0x04)
				}
			}
		}
	}

	function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := mul(gt(x, y), sub(x, y))
		}
	}

	function bound(uint256 x, uint256 lower, uint256 upper) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := xor(x, mul(xor(x, lower), gt(lower, x)))
			z := xor(z, mul(xor(z, upper), lt(upper, z)))
		}
	}

	function dist(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := add(xor(sub(0, gt(x, y)), sub(y, x)), gt(x, y))
		}
	}

	function rpow(uint256 x, uint256 y, uint256 base) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := mul(base, iszero(y))

			if x {
				z := xor(base, mul(xor(base, x), and(y, 1)))
				let half := shr(1, base)

				// prettier-ignore
				for { y := shr(1, y) } y { y := shr(1, y) } {
					let xx := mul(x, x)
					let xxRound := add(xx, half)

					if or(lt(xxRound, xx), shr(128, x)) {
						mstore(0x00, 0x35278d12) // Overflow()
						revert(0x1c, 0x04)
					}

					x := div(xxRound, base)

					if and(y, 1) {
						let zx := mul(z, x)
						let zxRound := add(zx, half)

						if or(xor(div(zx, x), z), lt(zxRound, zx)) {
							if x {
								mstore(0x00, 0x35278d12) // Overflow()
								revert(0x1c, 0x04)
							}
						}
						
						z := div(zxRound, base)
					}
				}
			}
		}
	}

	function sqrt(uint256 x) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := 181
			let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
			r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
			r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
			r := or(r, shl(4, lt(0xffffff, shr(r, x))))
			z := shl(shr(1, r), z)

			z := shr(18, mul(z, add(shr(r, x), 65536)))

			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))

			z := sub(z, lt(div(x, z), z))
		}
	}
}
