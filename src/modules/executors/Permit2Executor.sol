// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor, IModule} from "src/interfaces/IERC7579Modules.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {ReentrancyGuard} from "src/modules/utils/ReentrancyGuard.sol";
import {ExecutorBase} from "src/modules/base/ExecutorBase.sol";

/// @title Permit2Executor
/// @notice Executor module enabling smart accounts to manage ERC20 approvals via Permit2.
contract Permit2Executor is IExecutor, ExecutorBase, ReentrancyGuard {
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

	mapping(address account => bool) internal _isInstalled;

	address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

	/// @inheritdoc IModule
	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	/// @inheritdoc IModule
	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	/// @inheritdoc IModule
	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	/// @notice Approves the specified currencies for transfer via Permit2.
	/// @param params Encoded list of currency addresses to approve
	/// @return returnData The list of return values, including errors if using try mode
	function approveCurrencies(
		bytes calldata params
	) external payable nonReentrant returns (bytes[] memory returnData) {
		unchecked {
			uint256 length = _computeCurrenciesLength(params);
			Execution[] memory executions = new Execution[](length);

			for (uint256 i; i < length; ++i) {
				executions[i] = Execution({
					target: address(bytes20(params[i * 20:])),
					value: 0,
					callData: abi.encodeWithSelector(0x095ea7b3, PERMIT2, type(uint256).max)
				});
			}

			return _execute(executions);
		}
	}

	/// @notice Grants time-limited spending permission to a spender for a specified token and amount.
	/// @param currency The address of the ERC20 token
	/// @param spender The address receiving spending rights
	/// @param amount The token amount approved for spending
	/// @param expiration Unix timestamp after which the approval becomes invalid
	/// @return returnData The list of return values, including errors if using try mode
	function approve(
		Currency currency,
		address spender,
		uint160 amount,
		uint48 expiration
	) external payable nonReentrant returns (bytes[] memory returnData) {
		returnData = _execute(
			PERMIT2,
			0,
			abi.encodeWithSelector(
				0x87517c45, // approve(address,address,uint160,uint48)
				currency,
				spender,
				amount,
				expiration
			)
		);
	}

	/// @notice Permits a spender to use a specified amount of the owner's token using an EIP-712 signature.
	/// @param params Encoded PermitSingle struct followed by the owner's signature
	/// @return returnData The list of return values, including errors if using try mode
	function permitSingle(bytes calldata params) external payable nonReentrant returns (bytes[] memory returnData) {
		PermitSingle calldata permit;
		bytes calldata signature;

		assembly ("memory-safe") {
			permit := params.offset

			let ptr := add(params.offset, calldataload(add(params.offset, 0xc0)))
			signature.offset := add(ptr, 0x20)
			signature.length := calldataload(ptr)
		}

		returnData = _execute(
			PERMIT2,
			0,
			abi.encodeWithSelector(
				0x2b67b570, // permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)
				msg.sender,
				permit,
				signature
			)
		);
	}

	/// @notice Permits a spender to use a specified amount of the owner's token using an EIP-712 signature.
	/// @param params Encoded PermitBatch struct followed by the signature
	/// @return returnData The list of return values, including errors if using try mode
	function permitBatch(bytes calldata params) external payable nonReentrant returns (bytes[] memory returnData) {
		PermitBatch calldata permit;
		bytes calldata signature;

		assembly ("memory-safe") {
			permit := add(params.offset, calldataload(params.offset))

			let ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			signature.offset := add(ptr, 0x20)
			signature.length := calldataload(ptr)
		}

		returnData = _execute(
			PERMIT2,
			0,
			abi.encodeWithSelector(
				0x2a2d80d1, // permit(address,((address,uint160,uint48,uint48)[],address,uint256),bytes)
				msg.sender,
				permit,
				signature
			)
		);
	}

	/// @notice Returns the current nonce
	/// @param owner The address of the owner
	/// @param currency The address of the currency
	/// @param spender The address of the spender
	/// @return nonce The current nonce
	function getNonce(address owner, Currency currency, address spender) external view returns (uint48 nonce) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x927da10500000000000000000000000000000000000000000000000000000000) // allowance(address,address,address)
			mstore(add(ptr, 0x04), and(owner, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(spender, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), PERMIT2, ptr, 0x64, add(ptr, 0x64), 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			nonce := and(mload(add(ptr, 0xa4)), 0xffffffffffff)
		}
	}

	/// @notice Returns the name of the module
	/// @return The name of the module
	function name() external pure returns (string memory) {
		return "Permit2Executor";
	}

	/// @notice Returns the version of the module
	/// @return The version of the module
	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	/// @inheritdoc IModule
	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == MODULE_TYPE_EXECUTOR;
	}

	function _isInitialized(address account) internal view virtual returns (bool) {
		return _isInstalled[account];
	}

	function _computeCurrenciesLength(bytes calldata data) internal pure virtual returns (uint256 quotient) {
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
