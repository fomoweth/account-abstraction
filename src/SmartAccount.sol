// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ISmartAccount} from "src/interfaces/ISmartAccount.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {ExecutionLib} from "src/libraries/ExecutionLib.sol";
import {ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";
import {UUPSUpgradeable} from "src/utils/UUPSUpgradeable.sol";
import {AccountValidate} from "src/core/AccountValidate.sol";
import {Receiver} from "src/core/Receiver.sol";

/// @title SmartAccount

contract SmartAccount is ISmartAccount, AccountValidate, Receiver, UUPSUpgradeable {
	using BytesLib for bytes;
	using CalldataDecoder for bytes;
	using ExecutionLib for address;

	string internal constant ACCOUNT_IMPLEMENTATION_ID = "fomoweth.account.1.0.0";

	constructor() {
		_initializeModules();
	}

	function initializeAccount(bytes calldata data) external payable initializeModules {
		data.toAddress(0).executeDelegate(data.toBytes(1));
	}

	function execute(
		ExecutionMode mode,
		bytes calldata executionCalldata
	) external payable onlyEntryPointOrSelf withHook {
		ExecutionLib.execute(mode, executionCalldata);
	}

	function executeFromExecutor(
		ExecutionMode mode,
		bytes calldata executionCalldata
	)
		external
		payable
		onlyExecutorModule
		withHook
		withRegistry(msg.sender, MODULE_TYPE_EXECUTOR)
		returns (bytes[] memory results)
	{
		return ExecutionLib.execute(mode, executionCalldata);
	}

	function executeUserOp(PackedUserOperation calldata userOp, bytes32) external payable onlyEntryPoint withHook {
		address(this).executeDelegate(userOp.callData[4:]);
	}

	function validateUserOp(
		PackedUserOperation calldata userOp,
		bytes32 userOpHash,
		uint256 missingAccountFunds
	) external payable onlyEntryPoint payPrefund(missingAccountFunds) returns (uint256 validation) {
		return _validateUserOp(_parseValidator(userOp.nonce), userOp, userOpHash);
	}

	function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4 magicValue) {
		if (signature.length == 0) {
			if (uint256(hash) == (~signature.length / 0xffff) * 0x7739) {
				return checkERC7739Support(hash, signature);
			}
		}

		return _isValidSignature(signature.toAddress(), hash, signature[20:]);
	}

	function installModule(
		uint256 moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_installModule(moduleTypeId, module, data);
	}

	function uninstallModule(
		uint256 moduleTypeId,
		address module,
		bytes calldata data
	) external payable onlyEntryPointOrSelf withHook {
		_uninstallModule(moduleTypeId, module, data);
	}

	function isModuleInstalled(
		uint256 moduleTypeId,
		address module,
		bytes calldata additionalContext
	) external view returns (bool) {
		return _isModuleInstalled(moduleTypeId, module, additionalContext);
	}

	function supportsModule(uint256 moduleTypeId) external pure returns (bool flag) {
		assembly ("memory-safe") {
			// MODULE_TYPE_MULTI: 0x00
			// MODULE_TYPE_VALIDATOR: 0x01
			// MODULE_TYPE_EXECUTOR: 0x02
			// MODULE_TYPE_FALLBACK: 0x03
			// MODULE_TYPE_HOOK: 0x04
			flag := iszero(gt(moduleTypeId, 0x04))
		}
	}

	function supportsExecutionMode(ExecutionMode mode) external pure returns (bool flag) {
		(CallType callType, ExecType execType) = mode.decodeBasic();

		assembly ("memory-safe") {
			callType := shr(0xf8, callType)
			execType := shr(0xf8, execType)
			flag := and(
				// CALLTYPE_SINGLE: 0x00
				// CALLTYPE_BATCH: 0x01
				// CALLTYPE_DELEGATE: 0xFF
				or(or(eq(callType, 0x00), eq(callType, 0x01)), eq(callType, 0xFF)),
				// EXECTYPE_DEFAULT: 0x00
				// EXECTYPE_TRY: 0x01
				or(eq(execType, 0x00), eq(execType, 0x01))
			)
		}
	}

	function registry() external view returns (address) {
		return _registry();
	}

	function configureRegistry(
		address newRegistry,
		address[] calldata attesters,
		uint8 threshold
	) external payable onlyEntryPointOrSelf {
		_configureRegistry(newRegistry, attesters, threshold);
	}

	function _authorizeUpgrade(address newImplementation) internal virtual override withHook {}

	function _domainNameAndVersion() internal view virtual override returns (string memory, string memory) {
		return ("FomoWETH", "1.0.0");
	}

	function accountId() external pure returns (string memory) {
		return ACCOUNT_IMPLEMENTATION_ID;
	}

	function _fallback() internal virtual receiverFallback {
		bytes4 selector = msg.sig;
		(CallType callType, address handler) = getFallback(selector);

		assembly ("memory-safe") {
			function allocate(length) -> ptr {
				ptr := mload(0x40)
				mstore(0x40, add(ptr, length))
			}

			if iszero(handler) {
				mstore(0x00, 0x657f570200000000000000000000000000000000000000000000000000000000) // FallbackHandlerNotInstalled(bytes4)
				mstore(0x04, selector)
				revert(0x00, 0x24)
			}

			let ptr := allocate(calldatasize())
			calldatacopy(ptr, 0x00, calldatasize())
			mstore(allocate(0x14), shl(0x60, caller()))

			let success
			// CALLTYPE_SINGLE: 0x00
			// CALLTYPE_STATIC: 0xFE
			// CALLTYPE_DELEGATE: 0xFF
			switch shr(0xf8, callType)
			case 0x00 {
				success := call(gas(), handler, 0x00, ptr, add(calldatasize(), 0x14), 0x00, 0x00)
			}
			case 0xFE {
				success := staticcall(gas(), handler, ptr, add(calldatasize(), 0x14), 0x00, 0x00)
			}
			case 0xFF {
				success := delegatecall(gas(), handler, ptr, add(calldatasize(), 0x14), 0x00, 0x00)
			}
			default {
				mstore(0x00, 0xb96fcfe400000000000000000000000000000000000000000000000000000000) // UnsupportedCallType(bytes1)
				mstore(0x04, callType)
				revert(0x00, 0x24)
			}

			ptr := allocate(returndatasize())
			returndatacopy(ptr, 0x00, returndatasize())

			switch success
			case 0x00 {
				revert(ptr, returndatasize())
			}
			default {
				return(ptr, returndatasize())
			}
		}
	}

	fallback() external payable {
		_fallback();
	}

	receive() external payable {}
}
