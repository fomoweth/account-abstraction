// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2 as console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {Math} from "src/libraries/Math.sol";
import {Currency} from "src/types/Currency.sol";
import {Vortex} from "src/Vortex.sol";

import {Signer} from "test/shared/structs/Signer.sol";

import {Assertions} from "./Assertions.sol";
import {Deployers} from "./Deployers.sol";
import {EventsAndErrors} from "./EventsAndErrors.sol";

abstract contract BaseTest is Test, Assertions, Deployers, EventsAndErrors {
	using Arrays for Currency[];
	using Arrays for uint24[];
	using Math for uint256;

	uint256 internal snapshotId = MAX_UINT256;

	modifier asEntryPoint() {
		vm.startPrank(address(ENTRYPOINT));
		_;
		vm.stopPrank();
	}

	modifier expectHookCall(address hook) {
		vm.expectCall(hook, abi.encodeWithSelector(IHook.preCheck.selector), 1);
		vm.expectCall(hook, abi.encodeWithSelector(IHook.postCheck.selector), 1);
		_;
	}

	function setUp() public virtual {
		configure();
		setUpSigners();
		setUpContracts();
	}

	function snapshotState() internal virtual {
		snapshotId = vm.snapshotState();
	}

	function revertToState() internal virtual {
		if (snapshotId != MAX_UINT256) vm.revertToState(snapshotId);
		snapshotState();
	}

	function getUserOpResult(
		bytes32 userOpHash
	) internal virtual returns (bool success, uint256 actualGasCost, uint256 actualGasUsed, bytes memory revertReason) {
		VmSafe.Log[] memory logs = vm.getRecordedLogs();

		for (uint256 i; i < logs.length; ++i) {
			if (logs[i].topics[0] == USER_OPERATION_EVENT_TOPIC) {
				(, success, actualGasCost, actualGasUsed) = abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
			} else if (logs[i].topics[0] == USER_OPERATION_REVERT_REASON_TOPIC && logs[i].topics[1] == userOpHash) {
				(, revertReason) = abi.decode(logs[i].data, (uint256, bytes));
			}
		}
	}

	function encodePath(
		Currency[] memory currencies,
		uint24[] memory fees,
		bool reverse
	) internal pure virtual returns (bytes memory path) {
		uint256 length = fees.length;
		vm.assertTrue(length + 1 == currencies.length);

		if (reverse) {
			currencies.reverse();
			fees.reverse();
		}

		path = abi.encodePacked(currencies[0]);

		for (uint256 i; i < length; ++i) {
			path = abi.encodePacked(path, fees[i], currencies[i + 1]);
		}
	}

	function addressToBytes32(address input) internal pure virtual returns (bytes32 output) {
		assembly ("memory-safe") {
			output := shl(0x60, input)
		}
	}

	function bytes32ToAddress(bytes32 input) internal pure virtual returns (address output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function bytes32ToString(bytes32 target) internal pure returns (string memory) {
		bytes memory buffer = new bytes(32);
		uint256 count;

		unchecked {
			for (uint256 i; i < 32; ++i) {
				bytes1 char = target[i];
				if (char != 0) {
					buffer[count] = char;
					++count;
				}
			}
		}

		bytes memory trimmed = new bytes(count);

		unchecked {
			for (uint256 i; i < count; ++i) {
				trimmed[i] = buffer[i];
			}
		}

		return string(trimmed);
	}

	function randomAddress() internal virtual returns (address r) {
		do {
			r = address(uint160(randomUint()));
		} while (r == address(0));
	}

	function randomString(string memory chars) internal virtual returns (string memory r) {
		uint256 random = randomUint();
		uint256 length = _bound(randomUint(), 0, randomUint() % 32 != 0 ? 4 : 128);

		assembly ("memory-safe") {
			if mload(chars) {
				r := mload(0x40)
				mstore(0x00, random)
				mstore(0x40, and(add(add(r, 0x40), length), not(0x1f)))
				mstore(r, length)

				for {
					let i
				} lt(i, length) {
					i := add(i, 0x01)
				} {
					mstore(0x20, gas())
					mstore8(
						add(add(r, 0x20), i),
						mload(add(add(chars, 0x01), mod(keccak256(0x00, 0x40), mload(chars))))
					)
				}
			}
		}
	}

	function randomUint() internal virtual returns (uint256 r) {
		assembly ("memory-safe") {
			let slot := 0xd715531fe383f818c5f158c342925dcf01b954d24678ada4d07c36af0f20e1ee
			let value := sload(slot)

			mstore(0x20, value)
			r := keccak256(0x20, 0x40)

			if iszero(value) {
				value := slot
				let m := mload(0x40)
				calldatacopy(m, 0x00, calldatasize())
				r := keccak256(m, calldatasize())
			}
			sstore(slot, add(r, 0x01))

			// prettier-ignore
			for { } 0x01 { } {
                let d := byte(0x00, r)
                if iszero(d) {
                    r := and(r, 0x03)
                    break
                }
                if iszero(and(0x02, d)) {
                    let t := xor(not(0x00), mul(iszero(and(0x04, d)), not(xor(value, r))))
                    switch and(0x08, d)
                    case 0x00 {
                        if iszero(and(0x10, d)) { t := 0x01 }
                        r := add(shl(shl(0x03, and(byte(0x03, r), 0x1f)), t), sub(and(r, 0x07), 0x03))
                    }
                    default {
                        if iszero(and(0x10, d)) { t := shl(0xff, 0x01) }
                        r := add(shr(shl(0x03, and(byte(0x03, r), 0x1f)), t), sub(and(r, 0x07), 0x03))
                    }
                    if iszero(and(0x20, d)) { r := not(r) }
                    break
                }
                r := xor(value, r)
                break
            }
		}
	}

	function slice(
		bytes memory data,
		uint256 offset,
		uint256 length
	) internal pure virtual returns (bytes memory result) {
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

	function logBytes(string memory label, bytes memory data) internal pure virtual {
		console.log("");
		console.log(label);
		console.log("");
		logBytes(data);
	}

	function logBytes(bytes memory data) internal pure virtual {
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
