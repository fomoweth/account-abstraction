// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {CallType, ExecType, ModuleType} from "src/types/Types.sol";

abstract contract EventsAndErrors is CommonBase {
	// ERC-721
	event Transfer(address indexed from, address indexed to, uint256 indexed id);

	// ERC-1155
	event TransferSingle(
		address indexed operator,
		address indexed from,
		address indexed to,
		uint256 id,
		uint256 amount
	);

	event TransferBatch(
		address indexed operator,
		address indexed from,
		address indexed to,
		uint256[] ids,
		uint256[] amounts
	);

	// UUPSUpgradeable Proxy
	event Upgraded(address indexed implementation);

	// IEntryPoint
	event UserOperationEvent(
		bytes32 indexed userOpHash,
		address indexed sender,
		address indexed paymaster,
		uint256 nonce,
		bool success,
		uint256 actualGasCost,
		uint256 actualGasUsed
	);

	event AccountDeployed(bytes32 indexed userOpHash, address indexed sender, address factory, address paymaster);

	event BeforeExecution();

	event SignatureAggregatorChanged(address indexed aggregator);

	// IStakeManager
	event Deposited(address indexed account, uint256 totalDeposit);

	event Withdrawn(address indexed account, address recipient, uint256 amount);

	event StakeLocked(address indexed account, uint256 totalStaked, uint256 unstakeDelaySec);

	event StakeUnlocked(address indexed account, uint256 withdrawTime);

	event StakeWithdrawn(address indexed account, address recipient, uint256 amount);

	// ExecutionLib
	event TryExecuteUnsuccessful(uint256 index, bytes returnData);
	event TryExecuteUnsuccessful(bytes callData, bytes result);
	event TryDelegateCallUnsuccessful(bytes callData, bytes result);

	// MetaFactory
	event WhitelistSet(address indexed factory, bool indexed approval);

	// SmartAccountFactory
	event AccountCreated(address indexed account, bytes32 indexed salt);

	function expectEmit() internal virtual {
		vm.expectEmit();
	}

	function expectEmitTransferERC721(address from, address to, uint256 id) internal virtual {
		vm.expectEmit();
		emit Transfer(from, to, id);
	}

	function expectEmitTransferSingleERC1155(
		address operator,
		address from,
		address to,
		uint256 id,
		uint256 amount
	) internal virtual {
		vm.expectEmit();
		emit TransferSingle(operator, from, to, id, amount);
	}

	function expectEmitTransferBatchERC1155(
		address operator,
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts
	) internal virtual {
		vm.expectEmit();
		emit TransferBatch(operator, from, to, ids, amounts);
	}

	function expectEmitUpgraded(address implementation) internal virtual {
		vm.expectEmit();
		emit Upgraded(implementation);
	}

	function expectEmitDeposited(address account, uint256 totalDeposit) internal virtual {
		vm.expectEmit();
		emit Deposited(account, totalDeposit);
	}

	function expectEmitWithdrawn(address account, address recipient, uint256 amount) internal virtual {
		vm.expectEmit();
		emit Withdrawn(account, recipient, amount);
	}

	function expectEmitStakeLocked(address account, uint256 totalStaked, uint256 unstakeDelaySec) internal virtual {
		vm.expectEmit();
		emit StakeLocked(account, totalStaked, unstakeDelaySec);
	}

	function expectEmitStakeUnlocked(address account, uint256 withdrawTime) internal virtual {
		vm.expectEmit();
		emit StakeUnlocked(account, withdrawTime);
	}

	function expectEmitStakeWithdrawn(address account, address recipient, uint256 amount) internal virtual {
		vm.expectEmit();
		emit StakeWithdrawn(account, recipient, amount);
	}

	function expectEmitWhitelistSet(address factory, bool approval) internal virtual {
		// vm.expectEmit(true, true, true, true);
		vm.expectEmit();
		emit WhitelistSet(factory, approval);
	}

	// Common
	error InvalidCallValue(); // 0x21a64d90
	error LengthMismatch();

	// MetaFactory
	error AccountCreationFailed();
	error FactoryNotWhitelisted(address factory);
	error InvalidDataLength();
	error InvalidEntryPoint();
	error InvalidFactory();
	error InvalidRecipient();
	error InvalidThreshold();
	error InvalidEOAOwner();
	error InvalidK1Validator();
	error InvalidBootstrap();
	error InvalidERC7484Registry();

	// RegistryFactory
	error InvalidAttester();
	error AttestersNotSorted();
	error ModuleNotWhitelisted(address module, ModuleType moduleTypeId);
	error AttesterAlreadyExists(address attester);
	error AttesterNotExists(address attester);

	// SmartAccountFactory
	error InitializationFailed();
	error InvalidAccountImplementation();

	error ETHTransferFailed();

	// UUPSUpgradeable Proxy
	error InvalidImplementation();
	error UnauthorizedCallContext();
	error UpgradeFailed();

	// Ownable
	error Unauthorized();

	// CalldataDecoder
	error SliceOutOfBounds();

	// Modules
	error InvalidModule();
	error InvalidModuleTypeId(ModuleType moduleTypeId);
	error UnsupportedModuleType(ModuleType moduleTypeId);
	error ModuleAlreadyInstalled(address module);
	error ModuleNotInstalled(address module);
	error InvalidRootValidator();
	// error InvalidFlag(bytes1);
	error InvalidFlag();

	// ExecutionLib
	error UnsupportedCallType(CallType callType);
	error UnsupportedExecType(ExecType execType);
	error ExecutionFailed();

	// ERC-7579 Fallback
	error InvalidSelector();
	error ForbiddenSelector();
	error UnknownSelector(bytes4 selector);

	// ERC-7579 Modules
	error AlreadyInitialized(address account);
	error NotInitialized(address account);

	function expectRevert() internal virtual {
		vm.expectRevert();
	}

	function expectRevert(bytes4 selector) internal virtual {
		vm.expectRevert(selector);
	}
}
