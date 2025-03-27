// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console2 as console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

library Logger {
	Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	function slice(bytes memory data, uint256 offset, uint256 length) internal pure returns (bytes memory result) {
		assembly ("memory-safe") {
			result := mload(0x40)

			switch iszero(length)
			case 0x00 {
				let lengthmod := and(length, 0x1f)
				let ptr := add(add(result, lengthmod), mul(0x20, iszero(lengthmod)))
				let guard := add(ptr, length)

				for {
					let pos := add(add(add(data, lengthmod), mul(0x20, iszero(lengthmod))), offset)
				} lt(ptr, guard) {
					ptr := add(ptr, 0x20)
					pos := add(pos, 0x20)
				} {
					mstore(ptr, mload(pos))
				}

				mstore(result, length)
				mstore(0x40, and(add(ptr, 0x1f), not(0x1f)))
			}
			default {
				mstore(result, 0x00)
				mstore(0x40, add(result, 0x20))
			}
		}
	}

	function logBytes(string memory label, bytes memory data) internal pure {
		console.log("");
		console.log(label);
		console.log("");
		logBytes(data);
	}

	function logBytes(bytes memory data) internal pure {
		if (data.length % 32 == 4) {
			console.logBytes4(bytes4(data));
			data = slice(data, 4, data.length - 4);
		} else {
			console.log("0x");
		}

		for (uint256 i; i < data.length; i += 32) {
			console.log(vm.split(vm.toString(slice(data, i, 32)), "0x")[1]);
		}
	}
}
