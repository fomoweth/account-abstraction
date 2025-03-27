// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {Currency} from "src/types/Currency.sol";

import {PermitDetails, PermitSingle, PermitBatch} from "test/shared/structs/Protocols.sol";
import {Signer} from "test/shared/structs/Signer.sol";

import {Assertions} from "./Assertions.sol";
import {Deployers} from "./Deployers.sol";
import {EventsAndErrors} from "./EventsAndErrors.sol";

abstract contract BaseTest is Test, Assertions, Deployers, EventsAndErrors {
	string internal constant ENABLE_MODULE_NOTATION =
		"EnableModule(uint256 moduleTypeId,address module,bytes32 initDataHash,bytes32 userOpHash)";
	bytes32 internal constant ENABLE_MODULE_TYPEHASH = keccak256(bytes(ENABLE_MODULE_NOTATION));

	string internal constant PERMIT_DETAILS_NOTATION =
		"PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)";
	bytes32 internal constant PERMIT_DETAILS_TYPEHASH = keccak256(bytes(PERMIT_DETAILS_NOTATION));

	string internal constant PERMIT_SINGLE_NOTATION =
		"PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)";
	bytes32 internal constant PERMIT_SINGLE_TYPEHASH = keccak256(bytes(PERMIT_SINGLE_NOTATION));

	string internal constant PERMIT_BATCH_NOTATION =
		"PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)";
	bytes32 internal constant PERMIT_BATCH_TYPEHASH = keccak256(bytes(PERMIT_BATCH_NOTATION));

	// AccountDeployed(bytes32,address,address,address)
	bytes32 internal constant ACCOUNT_DEPLOYED_TOPIC =
		0xd51a9c61267aa6196961883ecf5ff2da6619c37dac0fa92122513fb32c032d2d;

	// UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)
	bytes32 internal constant USER_OPERATION_EVENT_TOPIC =
		0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f;

	// UserOperationRevertReason(bytes32,address,uint256,bytes)
	bytes32 internal constant USER_OPERATION_REVERT_REASON_TOPIC =
		0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201;

	bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	bytes32 internal constant STETH_TOTAL_SHARES_SLOT =
		0xe3b4b636e601189b5f4c6742edf2538ac12bb61ed03e6da26949d69838fa447e;

	bytes32 internal PERMIT2_DOMAIN_SEPARATOR;

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
		setUpSigners();
		setUpContracts();

		PERMIT2_DOMAIN_SEPARATOR = PERMIT2.DOMAIN_SEPARATOR();
	}

	function snapshotState() internal virtual {
		snapshotId = vm.snapshotState();
	}

	function revertToState() internal virtual {
		if (snapshotId != MAX_UINT256) vm.revertToState(snapshotId);
		snapshotState();
	}

	function deal(Currency currency, address account, uint256 value, bool adjust) internal virtual {
		if (currency.isZero()) {
			deal(account, value);
		} else if (currency == STETH) {
			(, bytes memory returndata) = currency.toAddress().staticcall(abi.encodeWithSelector(0xf5eb42dc, account));
			uint256 balancePrior = abi.decode(returndata, (uint256));
			bytes32 balanceSlot = keccak256(abi.encode(account, uint256(0)));
			vm.store(currency.toAddress(), balanceSlot, bytes32(value));

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				vm.store(currency.toAddress(), STETH_TOTAL_SHARES_SLOT, bytes32(totalSupply));
			}
		} else {
			deal(currency.toAddress(), account, value, adjust);
		}
	}

	function deal(Currency currency, address account, uint256 value) internal virtual {
		deal(currency, account, value, false);
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

	function preparePermitSingle(
		Signer memory signer,
		Currency currency,
		address spender
	) internal view virtual returns (PermitSingle memory permit, bytes memory signature, bytes32 hash) {
		(, , uint48 nonce) = PERMIT2.allowance(address(signer.account), currency, spender);

		permit = PermitSingle({
			details: PermitDetails({currency: currency, amount: MAX_UINT160, expiration: MAX_UINT48, nonce: nonce}),
			spender: spender,
			sigDeadline: MAX_UINT256
		});

		bytes32 structHash = keccak256(
			abi.encode(
				PERMIT_SINGLE_TYPEHASH,
				keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permit.details)),
				spender,
				MAX_UINT256
			)
		);

		hash = keccak256(abi.encodePacked("\x19\x01", PERMIT2_DOMAIN_SEPARATOR, structHash));

		signature = abi.encodePacked(signer.account.rootValidator(), signer.sign(hash));
	}

	function preparePermitBatch(
		Signer memory signer,
		Currency[] memory currencies,
		address spender
	) internal view virtual returns (PermitBatch memory permit, bytes memory signature, bytes32 hash) {
		uint256 length = currencies.length;
		PermitDetails[] memory details = new PermitDetails[](length);
		bytes32[] memory hashes = new bytes32[](length);

		for (uint256 i; i < length; ++i) {
			(, , uint48 nonce) = PERMIT2.allowance(address(signer.account), currencies[i], spender);

			hashes[i] = keccak256(
				abi.encode(
					PERMIT_DETAILS_TYPEHASH,
					details[i] = PermitDetails({
						currency: currencies[i],
						amount: MAX_UINT160,
						expiration: MAX_UINT48,
						nonce: nonce
					})
				)
			);
		}

		permit = PermitBatch({details: details, spender: spender, sigDeadline: MAX_UINT256});

		bytes32 structHash = keccak256(
			abi.encode(PERMIT_BATCH_TYPEHASH, keccak256(abi.encodePacked(hashes)), spender, MAX_UINT256)
		);

		hash = keccak256(abi.encodePacked("\x19\x01", PERMIT2_DOMAIN_SEPARATOR, structHash));

		signature = abi.encodePacked(signer.account.rootValidator(), signer.sign(hash));
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
}
