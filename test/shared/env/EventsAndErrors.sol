// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CallType, ExecType, ModuleType} from "src/types/Types.sol";

abstract contract EventsAndErrors {
	// UUPSUpgradeable Proxy
	event Upgraded(address indexed implementation);

	// MetaFactory
	event FactoryAuthorized(address indexed factory);
	event FactoryRevoked(address indexed factory);

	// AccountFactory
	event AccountCreated(address indexed account, bytes32 indexed salt);

	// Vortex
	event ModuleInstalled(ModuleType indexed moduleTypeId, address indexed module);
	event ModuleUninstalled(ModuleType indexed moduleTypeId, address indexed module);
	event RegistryConfigured(address indexed registry);
	event RootValidatorConfigured(address indexed rootValidator);
	event HookConfigured(address indexed module, address indexed hook);
	event TrustedForwarderConfigured(address indexed account, address indexed forwarder);
	event TryExecuteUnsuccessful(uint256 index, bytes returnData);

	// UUPSUpgradeable Proxy
	error InvalidImplementation();
	error UnauthorizedCallContext();
	error UpgradeFailed();

	// AccountFactory
	error AccountCreationFailed();
	error FactoryNotAuthorized(address factory);
	error InvalidAccountImplementation();
	error InvalidEntryPoint();
	error InvalidFactory();
	error InvalidK1Validator();
	error InvalidBootstrap();
	error InvalidERC7484Registry();
	error InvalidEOAOwner();
	error InvalidRecipient();

	// RegistryFactory
	error InvalidAttester();
	error InvalidThreshold();
	error AttestersNotSorted();
	error ModuleNotAuthorized(address module, ModuleType moduleTypeId);
	error AttesterAlreadyExists(address attester);
	error AttesterNotExists(address attester);

	// Vortex
	error ModuleAlreadyInstalled(address module);
	error ModuleNotInstalled(address module);

	error InvalidModule();
	error InvalidModuleType();
	error InvalidModuleTypeId();
	error UnsupportedModuleType(ModuleType moduleTypeId);
	error InvalidDataLength();

	error ForbiddenFallback();
	error ForbiddenSelector(bytes4 selector);
	error InvalidSelector();
	error UnknownSelector(bytes4 selector);

	error InvalidRootValidator();
	error InvalidFlagType(bytes1 flag);
	error InvalidFlag();
	error InvalidSignature();
	error EnableNotApproved();
	error InvalidInitialization();
	error InitializationFailed();

	// ExecutionLib
	error ExecutionFailed();
	error InvalidExecutionCalldata();
	error UnsupportedCallType(CallType callType);
	error UnsupportedExecType(ExecType execType);

	error SliceOutOfBounds();
	error InvalidWrappedNative();
	error TransferNativeFailed();
}
