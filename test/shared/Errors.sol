// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {CallType, ExecType} from "src/types/ExecutionMode.sol";

abstract contract Errors is CommonBase {
	// MetaFactory
	error AccountCreationFailed();
	error FactoryNotWhitelisted(address factory);
	error InvalidDataLength();
	error InvalidEntryPoint();
	error InvalidFactory();
	error InvalidRecipient();

	// SmartAccountFactory
	error InitializationFailed();
	error InvalidAccountImplementation();

	// ERC1967Clone
	error DeploymentFailed();
	error ETHTransferFailed();

	// UUPSUpgradeable Proxy
	error InvalidImplementation();
	error UnauthorizedCallContext();
	error UpgradeFailed();

	// Ownable
	error Unauthorized();

	// CalldataDecoder
	error SliceOutOfBounds();
	error InvalidSelector();

	// ModuleLib
	error InvalidModule(address module);
	error InvalidModuleTypeId(uint256 moduleTypeId);

	error ValidatorAlreadyInstalled(address validator);
	error ValidatorNotInstalled(address validator);
	error NoValidatorInstalled();

	error ExecutorAlreadyInstalled(address executor);
	error ExecutorNotInstalled(address executor);

	error FallbackHandlerAlreadyInstalled(address handler, bytes4 selector);
	error FallbackHandlerNotInstalled(bytes4 selector);

	error HookAlreadyInstalled(address hook);
	error HookNotInstalled(address hook);

	error LengthMismatch();

	// ExecutionLib
	error InvalidCallType();
	error InvalidExecType();

	// ExecutionModeLib
	error UnsupportedCallType(CallType callType);
	error UnsupportedExecType(ExecType execType);

	// SentinelListLibrary
	error EntryExistsAlready(address entry);
	error InitializedAlready();
	error InvalidEntry(address entry);
	error InvalidPage();

	function expectRevert() internal virtual {
		vm.expectRevert();
	}

	function expectRevert(bytes4 selector) internal virtual {
		vm.expectRevert(selector);
	}

	function expectRevertUnauthorized() internal virtual {
		vm.expectRevert(Unauthorized.selector);
	}

	function expectRevertAccountCreationFailed() internal virtual {
		vm.expectRevert(AccountCreationFailed.selector);
	}

	function expectRevertFactoryNotWhitelisted(address factory) internal virtual {
		vm.expectRevert(abi.encodeWithSelector(FactoryNotWhitelisted.selector, factory));
	}

	function expectRevertInvalidDataLength() internal virtual {
		vm.expectRevert(InvalidDataLength.selector);
	}

	function expectRevertInvalidEntryPoint() internal virtual {
		vm.expectRevert(InvalidEntryPoint.selector);
	}
}
