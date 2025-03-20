// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {Math} from "src/libraries/Math.sol";
import {Currency} from "src/types/Currency.sol";

abstract contract Assertions is CommonBase {
	uint256 internal constant DEFAULT_MAX_PERCENT_DELTA = 0.001e18;

	function isContract(address target) internal view virtual returns (bool result) {
		assembly ("memory-safe") {
			result := iszero(iszero(extcodesize(target)))
		}
	}

	function assertCloseTo(uint256 x, uint256 y, string memory err) internal view virtual {
		assertCloseTo(x, y, DEFAULT_MAX_PERCENT_DELTA, err);
	}

	function assertCloseTo(uint256 x, uint256 y) internal view virtual {
		assertCloseTo(x, y, DEFAULT_MAX_PERCENT_DELTA, "");
	}

	function assertCloseTo(uint256 x, uint256 y, uint256 maxPercentDelta) internal view virtual {
		assertCloseTo(x, y, maxPercentDelta, "");
	}

	function assertCloseTo(uint256 x, uint256 y, uint256 maxPercentDelta, string memory err) internal view virtual {
		if (y == 0) return vm.assertEq(x, y, err);

		uint256 delta = Math.max(x, y) - Math.min(x, y);
		uint256 percentDelta = (delta * 1e18) / y;
		vm.assertLt(percentDelta, maxPercentDelta, err);
	}

	function assertContract(address target) internal view virtual {
		vm.assertTrue(isContract(target));
	}

	function assertNotContract(address target) internal view virtual {
		vm.assertFalse(isContract(target));
	}

	function assertEq(Currency x, Currency y, string memory err) internal view virtual {
		vm.assertEq(x.toAddress(), y.toAddress(), err);
	}

	function assertEq(Currency x, Currency y) internal view virtual {
		vm.assertEq(x.toAddress(), y.toAddress());
	}
}
