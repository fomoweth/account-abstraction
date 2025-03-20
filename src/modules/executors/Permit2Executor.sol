// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BytesLib} from "src/libraries/BytesLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {ReentrancyGuard} from "src/modules/utils/ReentrancyGuard.sol";
import {ExecutorBase} from "src/modules/base/ExecutorBase.sol";

/// @title Permit2Executor

contract Permit2Executor is ExecutorBase, ReentrancyGuard {
	using BytesLib for *;
	using CalldataDecoder for bytes;

	struct PermitDetails {
		Currency currency;
		uint160 amount;
		uint48 expiration;
		uint48 nonce;
	}

	struct PermitSingle {
		PermitDetails details;
		address spender;
		uint256 sigDeadline;
	}

	struct PermitBatch {
		PermitDetails[] details;
		address spender;
		uint256 sigDeadline;
	}

	mapping(address account => bool isInstalled) internal _isInstalled;

	address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

	bytes4 internal constant APPROVE_SELECTOR = 0x095ea7b3;
	bytes4 internal constant PERMIT2_APPROVE_SELECTOR = 0x87517c45;
	bytes4 internal constant PERMIT2_PERMIT_SINGLE_SELECTOR = 0x2b67b570;
	bytes4 internal constant PERMIT2_PERMIT_BATCH_SELECTOR = 0x2a2d80d1;

	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;
	uint160 internal constant MAX_UINT160 = (1 << 160) - 1;
	uint48 internal constant MAX_UINT48 = (1 << 48) - 1;

	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function approveCurrencies(address account, bytes calldata data) external payable nonReentrant {
		unchecked {
			uint256 length = _getCurrenciesLength(data);
			Execution[] memory executions = new Execution[](length);

			for (uint256 i; i < length; ++i) {
				executions[i] = Execution({
					target: data[i * 20:].toAddress(),
					value: 0,
					callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
				});
			}

			_execute(account, executions);
		}
	}

	function approve(
		address account,
		Currency currency,
		address spender,
		uint160 amount,
		uint48 expiration
	) external payable nonReentrant {
		_execute(
			account,
			PERMIT2,
			0,
			abi.encodeWithSelector(PERMIT2_APPROVE_SELECTOR, currency, spender, amount, expiration)
		);
	}

	function approveMax(address account, Currency currency, address spender) external payable nonReentrant {
		_execute(
			account,
			PERMIT2,
			0,
			abi.encodeWithSelector(PERMIT2_APPROVE_SELECTOR, currency, spender, MAX_UINT160, MAX_UINT48)
		);
	}

	function permitSingle(
		address account,
		bytes calldata params // abi.encode(((address,uint160,uint48,uint48),address,uint256),bytes)
	) external payable nonReentrant {
		PermitSingle calldata permit;
		Currency currency;

		assembly ("memory-safe") {
			permit := params.offset
			currency := shr(0x60, shl(0x60, calldataload(params.offset)))
		}

		Execution[] memory executions = new Execution[](2);
		uint256 count;

		unchecked {
			if (currency.allowance(account, PERMIT2) != MAX_UINT256) {
				executions[count] = Execution({
					target: currency.toAddress(),
					value: 0,
					callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
				});
				++count;
			}

			executions[count] = Execution({
				target: PERMIT2,
				value: 0,
				callData: abi.encodeWithSelector(
					PERMIT2_PERMIT_SINGLE_SELECTOR,
					account,
					permit,
					params.toBytes(6) // signature
				)
			});
			++count;

			assembly ("memory-safe") {
				if xor(mload(executions), count) {
					mstore(executions, count)
				}
			}
		}

		_execute(account, executions);
	}

	function permitBatch(
		address account,
		bytes calldata params // abi.encode(((address,uint160,uint48,uint48)[],address,uint256),bytes)
	) external payable nonReentrant {
		PermitBatch calldata permit;

		assembly ("memory-safe") {
			permit := add(params.offset, calldataload(params.offset))
		}

		Execution[] memory executions;
		uint256 length = permit.details.length;
		uint256 count;

		unchecked {
			executions = new Execution[](length + 1);

			for (uint256 i; i < length; ++i) {
				Currency currency = permit.details[i].currency;

				if (currency.allowance(account, PERMIT2) != MAX_UINT256) {
					executions[count] = Execution({
						target: currency.toAddress(),
						value: 0,
						callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
					});
					++count;
				}
			}

			executions[count] = Execution({
				target: PERMIT2,
				value: 0,
				callData: abi.encodeWithSelector(
					PERMIT2_PERMIT_BATCH_SELECTOR,
					account,
					permit,
					params.toBytes(1) // signature
				)
			});
			++count;

			assembly ("memory-safe") {
				if xor(mload(executions), count) {
					mstore(executions, count)
				}
			}
		}

		_execute(account, executions);
	}

	function getNonce(address owner, Currency currency, address spender) external view returns (uint48 nonce) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x927da10500000000000000000000000000000000000000000000000000000000) // allowance(address,address,address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, owner)))
			mstore(add(ptr, 0x24), shr(0x60, shl(0x60, currency)))
			mstore(add(ptr, 0x44), shr(0x60, shl(0x60, spender)))

			if iszero(staticcall(gas(), PERMIT2, ptr, 0x64, add(ptr, 0x64), 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			nonce := and(mload(add(ptr, 0xa4)), 0xffffffffffff)
		}
	}

	function name() external pure returns (string memory) {
		return "Permit2Executor";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_EXECUTOR;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _isInstalled[account];
	}

	function _getCurrenciesLength(bytes calldata data) internal pure returns (uint256 quotient) {
		assembly ("memory-safe") {
			quotient := shr(0x40, mul(data.length, 0xCCCCCCCCCCCCD00))
			let remainder := sub(data.length, mul(quotient, 0x14))

			if iszero(iszero(remainder)) {
				mstore(0x00, 0xdfe93090) // InvalidDataLength()
				revert(0x1c, 0x04)
			}
		}
	}
}
