// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Arrays
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/LibSort.sol

library Arrays {
	function insertionSort(uint256[] memory array) internal pure {
		// prettier-ignore
		assembly ("memory-safe") {
            let n := mload(array)
            mstore(array, 0x00)
            let h := add(array, shl(0x05, n))
            let w := not(0x1f)
            for { let i := add(array, 0x20) } 0x01 { } {
                i := add(i, 0x20)
                if gt(i, h) { break }

                let k := mload(i)
                let j := add(i, w)
                let v := mload(j)
                if iszero(gt(v, k)) { continue }

                for { } 0x01 { } {
                    mstore(add(j, 0x20), v)
                    j := add(j, w)
                    v := mload(j)
                    if iszero(gt(v, k)) { break }
                }

                mstore(add(j, 0x20), k)
            }
            mstore(array, n)
        }
	}

	function insertionSort(int256[] memory array) internal pure {
		_flipSign(array);
		insertionSort(castToUint256s(array));
		_flipSign(array);
	}

	function insertionSort(address[] memory array) internal pure {
		insertionSort(castToUint256s(array));
	}

	function insertionSort(bytes32[] memory array) internal pure {
		insertionSort(castToUint256s(array));
	}

	function insertionSort(bytes4[] memory array) internal pure {
		insertionSort(castToUint256s(array));
	}

	function sort(uint256[] memory array) internal pure {
		// prettier-ignore
		assembly ("memory-safe") {
			function swap(val0, val1) -> res0, res1 {
				res1 := val0
				res0 := val1
			}

			function mswap(i, j) {
				let temp := mload(i)
				mstore(i, mload(j))
				mstore(j, temp)
			}

			function sortInner(w, l, h) {
				if iszero(gt(sub(h, l), 0x180)) {
                    let i := add(l, 0x20)
                    if iszero(lt(mload(l), mload(i))) { mswap(i, l) }

                    for { } 0x01 { } {
                        i := add(i, 0x20)
                        if gt(i, h) { break }

                        let k := mload(i)
                        let j := add(i, w)
                        let v := mload(j)
						if iszero(gt(v, k)) { continue }

						for { } 0x01 { } {
                            mstore(add(j, 0x20), v)
                            j := add(j, w)
                            v := mload(j)
                            if iszero(gt(v, k)) { break }
                        }
                        mstore(add(j, 0x20), k)
                    }
                    leave
                }

				let p := add(shl(0x05, shr(0x06, add(l, h))), and(0x1f, l))
				{
                    let e0 := mload(l)
                    let e1 := mload(p)
                    if iszero(lt(e0, e1)) { e0, e1 := swap(e0, e1) }
                    let e2 := mload(h)
                    if iszero(lt(e1, e2)) {
                        e1, e2 := swap(e1, e2)
                        if iszero(lt(e0, e1)) { e0, e1 := swap(e0, e1) }
                    }
                    mstore(h, e2)
                    mstore(p, e1)
                    mstore(l, e0)
                }

				{
                    let x := mload(p)
                    p := h
                    for { let i := l } 0x01 { } {
                        for { } 0x01 { } {
                            i := add(0x20, i)
                            if iszero(gt(x, mload(i))) { break }
                        }
                        let j := p
                        for { } 0x01 { } {
                            j := add(w, j)
                            if iszero(lt(x, mload(j))) { break }
                        }
                        p := j
                        if iszero(lt(i, p)) { break }
                        mswap(i, p)
                    }
                }
				if iszero(eq(add(p, 0x20), h)) { sortInner(w, add(p, 0x20), h) }
				if iszero(eq(p, l)) { sortInner(w, l, p) }
			}

			for { let n := mload(array) } iszero(lt(n, 2)) { } {
                let w := not(0x1f)
                let l := add(array, 0x20)
                let h := add(array, shl(0x05, n))
                let j := h
                for { } iszero(gt(mload(add(w, j)), mload(j))) { } { j := add(w, j) }
                if iszero(gt(j, l)) { break }

                for { j := h } iszero(lt(mload(add(w, j)), mload(j))) { } { j := add(w, j) }
                if iszero(gt(j, l)) {
                    for { } 0x01 { } {
                        let t := mload(l)
                        mstore(l, mload(h))
                        mstore(h, t)
                        h := add(w, h)
                        l := add(l, 0x20)
                        if iszero(lt(l, h)) { break }
                    }
                    break
                }
                mstore(array, 0x00)
                sortInner(w, l, h)
                mstore(array, n)
                break
            }
		}
	}

	function sort(int256[] memory array) internal pure {
		_flipSign(array);
		sort(castToUint256s(array));
		_flipSign(array);
	}

	function sort(address[] memory array) internal pure {
		sort(castToUint256s(array));
	}

	function sort(bytes32[] memory array) internal pure {
		sort(castToUint256s(array));
	}

	function sort(bytes4[] memory array) internal pure {
		sort(castToUint256s(array));
	}

	function uniquifySorted(uint256[] memory array) internal pure {
		// prettier-ignore
		assembly ("memory-safe") {
			if iszero(lt(mload(array), 0x02)) {
                let x := add(array, 0x20)
                let y := add(array, 0x40)
                let end := add(array, shl(0x05, add(mload(array), 0x01)))

                for { } 0x01 { } {
                    if iszero(eq(mload(x), mload(y))) {
                        x := add(x, 0x20)
                        mstore(x, mload(y))
                    }

                    y := add(y, 0x20)
                    if eq(y, end) { break }
                }

                mstore(array, shr(0x05, sub(x, array)))
            }
		}
	}

	function uniquifySorted(int256[] memory array) internal pure {
		uniquifySorted(castToUint256s(array));
	}

	function uniquifySorted(address[] memory array) internal pure {
		uniquifySorted(castToUint256s(array));
	}

	function uniquifySorted(bytes32[] memory array) internal pure {
		uniquifySorted(castToUint256s(array));
	}

	function uniquifySorted(bytes4[] memory array) internal pure {
		uniquifySorted(castToUint256s(array));
	}

	function searchSorted(uint256[] memory array, uint256 needle) internal pure returns (bool found, uint256 index) {
		(found, index) = _searchSorted(array, needle, 0);
	}

	function searchSorted(int256[] memory array, int256 needle) internal pure returns (bool found, uint256 index) {
		(found, index) = _searchSorted(castToUint256s(array), uint256(needle), 1 << 255);
	}

	function searchSorted(address[] memory array, address needle) internal pure returns (bool found, uint256 index) {
		(found, index) = _searchSorted(castToUint256s(array), uint160(needle), 0);
	}

	function searchSorted(bytes32[] memory array, bytes32 needle) internal pure returns (bool found, uint256 index) {
		(found, index) = _searchSorted(castToUint256s(array), uint256(needle), 0);
	}

	function searchSorted(bytes4[] memory array, bytes4 needle) internal pure returns (bool found, uint256 index) {
		(found, index) = _searchSorted(castToUint256s(array), uint256((bytes32(needle))), 0);
	}

	function inSorted(uint256[] memory array, uint256 needle) internal pure returns (bool found) {
		(found, ) = searchSorted(array, needle);
	}

	function inSorted(int256[] memory array, int256 needle) internal pure returns (bool found) {
		(found, ) = searchSorted(array, needle);
	}

	function inSorted(address[] memory array, address needle) internal pure returns (bool found) {
		(found, ) = searchSorted(array, needle);
	}

	function inSorted(bytes32[] memory array, bytes32 needle) internal pure returns (bool found) {
		(found, ) = searchSorted(array, needle);
	}

	function inSorted(bytes4[] memory array, bytes4 needle) internal pure returns (bool found) {
		(found, ) = searchSorted(array, needle);
	}

	function reverse(uint256[] memory array) internal pure {
		// prettier-ignore
		assembly ("memory-safe") {
			if iszero(lt(mload(array), 0x02)) {
                let s := 0x20
                let w := not(0x1f)
                let h := add(array, shl(0x05, mload(array)))
                for { array := add(array, s) } 0x01 { } {
                    let t := mload(array)
                    mstore(array, mload(h))
                    mstore(h, t)
                    h := add(h, w)
                    array := add(array, s)
                    if iszero(lt(array, h)) { break }
                }
            }
		}
	}

	function reverse(int256[] memory array) internal pure {
		reverse(castToUint256s(array));
	}

	function reverse(address[] memory array) internal pure {
		reverse(castToUint256s(array));
	}

	function reverse(bytes32[] memory array) internal pure {
		reverse(castToUint256s(array));
	}

	function reverse(bytes4[] memory array) internal pure {
		reverse(castToUint256s(array));
	}

	function copy(uint256[] memory array) internal pure returns (uint256[] memory result) {
		// prettier-ignore
		assembly ("memory-safe") {
			result := mload(0x40)
			let end := add(add(result, 0x20), shl(0x05, mload(array)))
			let o := result
			for { let d := sub(array, result) } 0x01 { } {
                mstore(o, mload(add(o, d)))
                o := add(0x20, o)
                if eq(o, end) { break }
            }
			mstore(0x40, o)
		}
	}

	function copy(int256[] memory array) internal pure returns (int256[] memory result) {
		result = castToInt256s(copy(castToUint256s(array)));
	}

	function copy(address[] memory array) internal pure returns (address[] memory result) {
		result = castToAddresses(copy(castToUint256s(array)));
	}

	function copy(bytes32[] memory array) internal pure returns (bytes32[] memory result) {
		result = castToBytes32s(copy(castToUint256s(array)));
	}

	function copy(bytes4[] memory array) internal pure returns (bytes4[] memory result) {
		result = castToBytes4s(copy(castToUint256s(array)));
	}

	function isSorted(uint256[] memory array) internal pure returns (bool result) {
		// prettier-ignore
		assembly ("memory-safe") {
			result := 0x01
			if iszero(lt(mload(array), 0x02)) {
                let end := add(array, shl(0x05, mload(array)))
                for { array := add(array, 0x20) } 0x01 { } {
                    let p := mload(array)
                    array := add(array, 0x20)
                    result := iszero(gt(p, mload(array)))
                    if iszero(mul(result, xor(array, end))) { break }
                }
            }
		}
	}

	function isSorted(int256[] memory array) internal pure returns (bool result) {
		// prettier-ignore
		assembly ("memory-safe") {
			result := 0x01
			if iszero(lt(mload(array), 0x02)) {
                let end := add(array, shl(0x05, mload(array)))
                for { array := add(array, 0x20) } 0x01 { } {
                    let p := mload(array)
                    array := add(array, 0x20)
                    result := iszero(sgt(p, mload(array)))
                    if iszero(mul(result, xor(array, end))) { break }
                }
            }
		}
	}

	function isSorted(address[] memory array) internal pure returns (bool result) {
		result = isSorted(castToUint256s(array));
	}

	function isSorted(bytes32[] memory array) internal pure returns (bool result) {
		result = isSorted(castToUint256s(array));
	}

	function isSorted(bytes4[] memory array) internal pure returns (bool result) {
		result = isSorted(castToUint256s(array));
	}

	function isSortedAndUniquified(uint256[] memory array) internal pure returns (bool result) {
		// prettier-ignore
		assembly ("memory-safe") {
			result := 0x01
			if iszero(lt(mload(array), 0x02)) {
                let end := add(array, shl(0x05, mload(array)))
                for { array := add(array, 0x20) } 0x01 { } {
                    let p := mload(array)
                    array := add(array, 0x20)
                    result := lt(p, mload(array))
                    if iszero(mul(result, xor(array, end))) { break }
                }
            }
		}
	}

	function isSortedAndUniquified(int256[] memory array) internal pure returns (bool result) {
		// prettier-ignore
		assembly ("memory-safe") {
			result := 0x01
			if iszero(lt(mload(array), 0x02)) {
                let end := add(array, shl(0x05, mload(array)))
                for { array := add(array, 0x20) } 0x01 { } {
                    let p := mload(array)
                    array := add(array, 0x20)
                    result := slt(p, mload(array))
                    if iszero(mul(result, xor(array, end))) { break }
                }
            }
		}
	}

	function isSortedAndUniquified(address[] memory array) internal pure returns (bool) {
		return isSortedAndUniquified(castToUint256s(array));
	}

	function isSortedAndUniquified(bytes32[] memory array) internal pure returns (bool) {
		return isSortedAndUniquified(castToUint256s(array));
	}

	function isSortedAndUniquified(bytes4[] memory array) internal pure returns (bool) {
		return isSortedAndUniquified(castToUint256s(array));
	}

	function difference(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
		return _difference(a, b, 0);
	}

	function difference(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
		return castToInt256s(_difference(castToUint256s(a), castToUint256s(b), 1 << 255));
	}

	function difference(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
		return castToAddresses(_difference(castToUint256s(a), castToUint256s(b), 0));
	}

	function difference(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
		return castToBytes32s(_difference(castToUint256s(a), castToUint256s(b), 0));
	}

	function difference(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory c) {
		return castToBytes4s(_difference(castToUint256s(a), castToUint256s(b), 0));
	}

	function intersection(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
		return _intersection(a, b, 0);
	}

	function intersection(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
		return castToInt256s(_intersection(castToUint256s(a), castToUint256s(b), 1 << 255));
	}

	function intersection(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
		return castToAddresses(_intersection(castToUint256s(a), castToUint256s(b), 0));
	}

	function intersection(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
		return castToBytes32s(_intersection(castToUint256s(a), castToUint256s(b), 0));
	}

	function intersection(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory c) {
		return castToBytes4s(_intersection(castToUint256s(a), castToUint256s(b), 0));
	}

	function union(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
		return _union(a, b, 0);
	}

	function union(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
		return castToInt256s(_union(castToUint256s(a), castToUint256s(b), 1 << 255));
	}

	function union(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
		return castToAddresses(_union(castToUint256s(a), castToUint256s(b), 0));
	}

	function union(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
		return castToBytes32s(_union(castToUint256s(a), castToUint256s(b), 0));
	}

	function union(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory c) {
		return castToBytes4s(_union(castToUint256s(a), castToUint256s(b), 0));
	}

	function clean(address[] memory array) internal pure {
		// prettier-ignore
		assembly ("memory-safe") {
			let addressMask := shr(0x60, not(0x00))
			for { let end := add(array, shl(0x05, mload(array))) } iszero(eq(array, end)) { } {
                array := add(array, 0x20)
                mstore(array, and(mload(array), addressMask))
            }
		}
	}

	function castToBytes4s(bytes32[] memory input) internal pure returns (bytes4[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes4s(uint256[] memory input) internal pure returns (bytes4[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256s(bytes4[] memory input) internal pure returns (uint256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32s(bytes4[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32s(uint256[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256s(bytes32[] memory input) internal pure returns (uint256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToInt256s(uint256[] memory input) internal pure returns (int256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256s(int256[] memory input) internal pure returns (uint256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToAddresses(uint256[] memory input) internal pure returns (address[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256s(address[] memory input) internal pure returns (uint256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function _searchSorted(
		uint256[] memory array,
		uint256 needle,
		uint256 signed
	) private pure returns (bool found, uint256 index) {
		// prettier-ignore
		assembly ("memory-safe") {
            let w := not(0x00)
            let l := 0x01
            let h := mload(array)
            let t := 0x00
            for { needle := add(signed, needle) } 0x01 { } {
                index := shr(0x01, add(l, h))
                t := add(signed, mload(add(array, shl(0x05, index))))
                if or(gt(l, h), eq(t, needle)) { break }

                if iszero(gt(needle, t)) {
                    h := add(index, w)
                    continue
                }
                l := add(index, 0x01)
            }

            found := eq(t, needle)
            t := iszero(iszero(index))
            index := mul(add(index, w), t)
            found := and(found, t)
        }
	}

	function _difference(
		uint256[] memory a,
		uint256[] memory b,
		uint256 signed
	) private pure returns (uint256[] memory c) {
		// prettier-ignore
		assembly ("memory-safe") {
            let s := 0x20
            let aEnd := add(a, shl(0x05, mload(a)))
            let bEnd := add(b, shl(0x05, mload(b)))
            c := mload(0x40)
            a := add(a, s)
            b := add(b, s)
            let k := c
            for { } iszero(or(gt(a, aEnd), gt(b, bEnd))) { } {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    b := add(b, s)
                    continue
                }
                k := add(k, s)
                mstore(k, u)
                a := add(a, s)
            }
            for { } iszero(gt(a, aEnd)) { } {
                k := add(k, s)
                mstore(k, mload(a))
                a := add(a, s)
            }
            mstore(c, shr(0x05, sub(k, c)))
            mstore(0x40, add(k, s))
        }
	}

	function _intersection(
		uint256[] memory a,
		uint256[] memory b,
		uint256 signed
	) private pure returns (uint256[] memory c) {
		// prettier-ignore
		assembly ("memory-safe") {
            let s := 0x20
            let aEnd := add(a, shl(0x05, mload(a)))
            let bEnd := add(b, shl(0x05, mload(b)))
            c := mload(0x40)
            a := add(a, s)
            b := add(b, s)
            let k := c
            for { } iszero(or(gt(a, aEnd), gt(b, bEnd))) { } {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    k := add(k, s)
                    mstore(k, u)
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    b := add(b, s)
                    continue
                }
                a := add(a, s)
            }
            mstore(c, shr(0x05, sub(k, c)))
            mstore(0x40, add(k, s))
        }
	}

	function _union(uint256[] memory a, uint256[] memory b, uint256 signed) private pure returns (uint256[] memory c) {
		// prettier-ignore
		assembly ("memory-safe") {
            let s := 0x20
            let aEnd := add(a, shl(0x05, mload(a)))
            let bEnd := add(b, shl(0x05, mload(b)))
            c := mload(0x40)
            a := add(a, s)
            b := add(b, s)
            let k := c
            for { } iszero(or(gt(a, aEnd), gt(b, bEnd))) { } {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    k := add(k, s)
                    mstore(k, u)
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    k := add(k, s)
                    mstore(k, v)
                    b := add(b, s)
                    continue
                }
                k := add(k, s)
                mstore(k, u)
                a := add(a, s)
            }
            for { } iszero(gt(a, aEnd)) { } {
                k := add(k, s)
                mstore(k, mload(a))
                a := add(a, s)
            }
            for { } iszero(gt(b, bEnd)) { } {
                k := add(k, s)
                mstore(k, mload(b))
                b := add(b, s)
            }
            mstore(c, shr(0x05, sub(k, c)))
            mstore(0x40, add(k, s))
        }
	}

	function _flipSign(int256[] memory array) private pure {
		// prettier-ignore
		assembly ("memory-safe") {
			let w := shl(0xff, 0x01)
			for { let end := add(array, shl(0x05, mload(array))) } iszero(eq(array, end)) { } {
                array := add(array, 0x20)
                mstore(array, add(mload(array), w))
            }
		}
	}
}
