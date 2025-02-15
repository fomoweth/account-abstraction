// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPointSimulations, IEntryPoint} from "account-abstraction/interfaces/IEntryPointSimulations.sol";
import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {IAccountExecute} from "account-abstraction/interfaces/IAccountExecute.sol";
import {IAggregator} from "account-abstraction/interfaces/IAggregator.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS, ValidationData, min, _parseValidationData} from "account-abstraction/core/Helpers.sol";
import {NonceManager, INonceManager} from "account-abstraction/core/NonceManager.sol";
import {SenderCreator} from "account-abstraction/core/SenderCreator.sol";
import {StakeManager, IStakeManager} from "account-abstraction/core/StakeManager.sol";
import {PackedUserOperation, UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {Exec} from "account-abstraction/utils/Exec.sol";
import {ERC165} from "@openzeppelin/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

address constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

contract EntryPointSimulations is IEntryPointSimulations, StakeManager, NonceManager, ReentrancyGuard, ERC165 {
	using UserOperationLib for PackedUserOperation;

	AggregatorStakeInfo private NOT_AGGREGATED = AggregatorStakeInfo(address(0), StakeInfo(0, 0));

	uint256 private constant INNER_GAS_OVERHEAD = 10000;

	// Marker for inner call revert on out of gas
	bytes32 private constant INNER_OUT_OF_GAS = hex"deaddead";
	bytes32 private constant INNER_REVERT_LOW_PREFUND = hex"deadaa51";

	uint256 private constant REVERT_REASON_MAX_LEN = 2048;
	uint256 private constant PENALTY_PERCENT = 10;

	SenderCreator private immutable _senderCreator = initSenderCreator();

	function initSenderCreator() internal virtual returns (SenderCreator) {
		address createdObj = address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", ENTRYPOINT, hex"01")))));
		return SenderCreator(createdObj);
	}

	function senderCreator() internal view virtual returns (SenderCreator) {
		return _senderCreator;
	}

	// Phase 0: account creation
	// Phase 1: validation
	// Phase 2: execution
	mapping(address account => mapping(uint256 phase => uint256 gas)) internal gasConsumed;

	function setGasConsumed(address account, uint256 phase, uint256 gas) internal virtual {
		gasConsumed[account][phase] = gas;
	}

	function getGasConsumed(address account, uint256 phase) public view virtual returns (uint256) {
		return gasConsumed[account][phase];
	}

	function simulateValidation(PackedUserOperation calldata userOp) external returns (ValidationResult memory) {
		UserOpInfo memory outOpInfo;

		_simulationOnlyValidations(userOp);
		(uint256 validationData, uint256 paymasterValidationData) = _validatePrepayment(0, userOp, outOpInfo);
		StakeInfo memory paymasterInfo = _getStakeInfo(outOpInfo.mUserOp.paymaster);
		StakeInfo memory senderInfo = _getStakeInfo(outOpInfo.mUserOp.sender);
		StakeInfo memory factoryInfo;
		{
			bytes calldata initCode = userOp.initCode;
			address factory = initCode.length >= 20 ? address(bytes20(initCode[0:20])) : address(0);
			factoryInfo = _getStakeInfo(factory);
		}

		address aggregator = address(uint160(validationData));
		ReturnInfo memory returnInfo = ReturnInfo(
			outOpInfo.preOpGas,
			outOpInfo.prefund,
			validationData,
			paymasterValidationData,
			getMemoryBytesFromOffset(outOpInfo.contextOffset)
		);

		AggregatorStakeInfo memory aggregatorInfo = NOT_AGGREGATED;
		if (uint160(aggregator) != SIG_VALIDATION_SUCCESS && uint160(aggregator) != SIG_VALIDATION_FAILED) {
			aggregatorInfo = AggregatorStakeInfo(aggregator, _getStakeInfo(aggregator));
		}
		return ValidationResult(returnInfo, senderInfo, factoryInfo, paymasterInfo, aggregatorInfo);
	}

	function simulateHandleOp(
		PackedUserOperation calldata op,
		address target,
		bytes calldata targetCallData
	) external nonReentrant returns (ExecutionResult memory) {
		UserOpInfo memory opInfo;
		_simulationOnlyValidations(op);
		(uint256 validationData, uint256 paymasterValidationData) = _validatePrepayment(0, op, opInfo);

		uint256 paid = _executeUserOp(0, op, opInfo);
		bool targetSuccess;
		bytes memory targetResult;
		if (target != address(0)) {
			(targetSuccess, targetResult) = target.call(targetCallData);
		}
		return
			ExecutionResult(
				opInfo.preOpGas,
				paid,
				validationData,
				paymasterValidationData,
				targetSuccess,
				targetResult
			);
	}

	function _simulationOnlyValidations(PackedUserOperation calldata userOp) internal virtual {
		try this._validateSenderAndPaymaster(userOp.initCode, userOp.sender, userOp.paymasterAndData) {} catch Error(
			string memory revertReason
		) {
			if (bytes(revertReason).length != 0) {
				revert FailedOp(0, revertReason);
			}
		}
	}

	function _validateSenderAndPaymaster(
		bytes calldata initCode,
		address sender,
		bytes calldata paymasterAndData
	) external view {
		if (initCode.length == 0 && sender.code.length == 0) {
			// it would revert anyway. but give a meaningful message
			revert("AA20 account not deployed");
		}
		if (paymasterAndData.length >= 20) {
			address paymaster = address(bytes20(paymasterAndData[0:20]));
			if (paymaster.code.length == 0) {
				// It would revert anyway. but give a meaningful message.
				revert("AA30 paymaster not deployed");
			}
		}
		// always revert
		revert("");
	}

	function depositTo(address account) public payable override(IStakeManager, StakeManager) {
		unchecked {
			// silly code, to waste some gas to make sure depositTo is always little more
			// expensive than on-chain call
			uint256 x = 1;
			while (x < 5) {
				x++;
			}
			StakeManager.depositTo(account);
		}
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		return
			interfaceId ==
			(type(IEntryPoint).interfaceId ^ type(IStakeManager).interfaceId ^ type(INonceManager).interfaceId) ||
			interfaceId == type(IEntryPoint).interfaceId ||
			interfaceId == type(IStakeManager).interfaceId ||
			interfaceId == type(INonceManager).interfaceId ||
			super.supportsInterface(interfaceId);
	}

	function _compensate(address payable beneficiary, uint256 amount) internal {
		require(beneficiary != address(0), "AA90 invalid beneficiary");
		(bool success, ) = beneficiary.call{value: amount}("");
		require(success, "AA91 failed send to beneficiary");
	}

	function _executeUserOp(
		uint256 opIndex,
		PackedUserOperation calldata userOp,
		UserOpInfo memory opInfo
	) internal returns (uint256 collected) {
		uint256 preGas = gasleft();
		bytes memory context = getMemoryBytesFromOffset(opInfo.contextOffset);
		bool success;
		{
			uint256 saveFreePtr;
			assembly ("memory-safe") {
				saveFreePtr := mload(0x40)
			}
			bytes calldata callData = userOp.callData;
			bytes memory innerCall;
			bytes4 methodSig;
			assembly ("memory-safe") {
				let len := callData.length
				if gt(len, 3) {
					methodSig := calldataload(callData.offset)
				}
			}
			if (methodSig == IAccountExecute.executeUserOp.selector) {
				bytes memory executeUserOp = abi.encodeCall(IAccountExecute.executeUserOp, (userOp, opInfo.userOpHash));
				innerCall = abi.encodeCall(this.innerHandleOp, (executeUserOp, opInfo, context));
			} else {
				innerCall = abi.encodeCall(this.innerHandleOp, (callData, opInfo, context));
			}
			assembly ("memory-safe") {
				success := call(gas(), address(), 0, add(innerCall, 0x20), mload(innerCall), 0, 32)
				collected := mload(0)
				mstore(0x40, saveFreePtr)
			}
		}
		if (!success) {
			bytes32 innerRevertCode;
			assembly ("memory-safe") {
				let len := returndatasize()
				if eq(32, len) {
					returndatacopy(0, 0, 32)
					innerRevertCode := mload(0)
				}
			}
			if (innerRevertCode == INNER_OUT_OF_GAS) {
				// handleOps was called with gas limit too low. abort entire bundle.
				//can only be caused by bundler (leaving not enough gas for inner call)
				revert FailedOp(opIndex, "AA95 out of gas");
			} else if (innerRevertCode == INNER_REVERT_LOW_PREFUND) {
				// innerCall reverted on prefund too low. treat entire prefund as "gas cost"
				uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
				uint256 actualGasCost = opInfo.prefund;
				emitPrefundTooLow(opInfo);
				emitUserOperationEvent(opInfo, false, actualGasCost, actualGas);
				collected = actualGasCost;
			} else {
				emit PostOpRevertReason(
					opInfo.userOpHash,
					opInfo.mUserOp.sender,
					opInfo.mUserOp.nonce,
					Exec.getReturnData(REVERT_REASON_MAX_LEN)
				);

				uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
				collected = _postExecution(IPaymaster.PostOpMode.postOpReverted, opInfo, context, actualGas);
			}
		}
	}

	function emitUserOperationEvent(
		UserOpInfo memory opInfo,
		bool success,
		uint256 actualGasCost,
		uint256 actualGas
	) internal virtual {
		emit UserOperationEvent(
			opInfo.userOpHash,
			opInfo.mUserOp.sender,
			opInfo.mUserOp.paymaster,
			opInfo.mUserOp.nonce,
			success,
			actualGasCost,
			actualGas
		);
	}

	function emitPrefundTooLow(UserOpInfo memory opInfo) internal virtual {
		emit UserOperationPrefundTooLow(opInfo.userOpHash, opInfo.mUserOp.sender, opInfo.mUserOp.nonce);
	}

	function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) public nonReentrant {
		uint256 opslen = ops.length;
		UserOpInfo[] memory opInfos = new UserOpInfo[](opslen);

		unchecked {
			for (uint256 i = 0; i < opslen; i++) {
				UserOpInfo memory opInfo = opInfos[i];
				(uint256 validationData, uint256 pmValidationData) = _validatePrepayment(i, ops[i], opInfo);
				_validateAccountAndPaymasterValidationData(i, validationData, pmValidationData, address(0));
			}

			uint256 collected = 0;
			emit BeforeExecution();

			for (uint256 i = 0; i < opslen; i++) {
				collected += _executeUserOp(i, ops[i], opInfos[i]);
			}

			_compensate(beneficiary, collected);
		}
	}

	function handleAggregatedOps(
		UserOpsPerAggregator[] calldata opsPerAggregator,
		address payable beneficiary
	) public nonReentrant {
		uint256 opasLen = opsPerAggregator.length;
		uint256 totalOps = 0;
		for (uint256 i = 0; i < opasLen; i++) {
			UserOpsPerAggregator calldata opa = opsPerAggregator[i];
			PackedUserOperation[] calldata ops = opa.userOps;
			IAggregator aggregator = opa.aggregator;

			//address(1) is special marker of "signature error"
			require(address(aggregator) != address(1), "AA96 invalid aggregator");

			if (address(aggregator) != address(0)) {
				try aggregator.validateSignatures(ops, opa.signature) {} catch {
					revert SignatureValidationFailed(address(aggregator));
				}
			}

			totalOps += ops.length;
		}

		UserOpInfo[] memory opInfos = new UserOpInfo[](totalOps);

		uint256 opIndex = 0;
		for (uint256 a = 0; a < opasLen; a++) {
			UserOpsPerAggregator calldata opa = opsPerAggregator[a];
			PackedUserOperation[] calldata ops = opa.userOps;
			IAggregator aggregator = opa.aggregator;

			uint256 opslen = ops.length;
			for (uint256 i = 0; i < opslen; i++) {
				UserOpInfo memory opInfo = opInfos[opIndex];
				(uint256 validationData, uint256 paymasterValidationData) = _validatePrepayment(
					opIndex,
					ops[i],
					opInfo
				);
				_validateAccountAndPaymasterValidationData(
					i,
					validationData,
					paymasterValidationData,
					address(aggregator)
				);
				opIndex++;
			}
		}

		emit BeforeExecution();

		uint256 collected = 0;
		opIndex = 0;
		for (uint256 a = 0; a < opasLen; a++) {
			UserOpsPerAggregator calldata opa = opsPerAggregator[a];
			emit SignatureAggregatorChanged(address(opa.aggregator));
			PackedUserOperation[] calldata ops = opa.userOps;
			uint256 opslen = ops.length;

			for (uint256 i = 0; i < opslen; i++) {
				collected += _executeUserOp(opIndex, ops[i], opInfos[opIndex]);
				opIndex++;
			}
		}
		emit SignatureAggregatorChanged(address(0));

		_compensate(beneficiary, collected);
	}

	struct MemoryUserOp {
		address sender;
		uint256 nonce;
		uint256 verificationGasLimit;
		uint256 callGasLimit;
		uint256 paymasterVerificationGasLimit;
		uint256 paymasterPostOpGasLimit;
		uint256 preVerificationGas;
		address paymaster;
		uint256 maxFeePerGas;
		uint256 maxPriorityFeePerGas;
	}

	struct UserOpInfo {
		MemoryUserOp mUserOp;
		bytes32 userOpHash;
		uint256 prefund;
		uint256 contextOffset;
		uint256 preOpGas;
	}

	function innerHandleOp(
		bytes memory callData,
		UserOpInfo memory opInfo,
		bytes calldata context
	) external returns (uint256 actualGasCost) {
		uint256 preGas = gasleft();
		require(msg.sender == address(this), "AA92 internal call only");
		MemoryUserOp memory mUserOp = opInfo.mUserOp;

		uint256 callGasLimit = mUserOp.callGasLimit;
		unchecked {
			// handleOps was called with gas limit too low. abort entire bundle.
			if ((gasleft() * 63) / 64 < callGasLimit + mUserOp.paymasterPostOpGasLimit + INNER_GAS_OVERHEAD) {
				assembly ("memory-safe") {
					mstore(0, INNER_OUT_OF_GAS)
					revert(0, 32)
				}
			}
		}

		IPaymaster.PostOpMode mode = IPaymaster.PostOpMode.opSucceeded;
		if (callData.length > 0) {
			uint256 _execGas = gasleft();
			bool success = Exec.call(mUserOp.sender, 0, callData, callGasLimit);
			setGasConsumed(mUserOp.sender, 2, _execGas - gasleft());
			if (!success) {
				bytes memory result = Exec.getReturnData(REVERT_REASON_MAX_LEN);
				if (result.length > 0) {
					emit UserOperationRevertReason(opInfo.userOpHash, mUserOp.sender, mUserOp.nonce, result);
				}
				mode = IPaymaster.PostOpMode.opReverted;
			}
		}

		unchecked {
			uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
			return _postExecution(mode, opInfo, context, actualGas);
		}
	}

	function getUserOpHash(PackedUserOperation calldata userOp) public view returns (bytes32) {
		return keccak256(abi.encode(userOp.hash(), address(this), block.chainid));
	}

	function _copyUserOpToMemory(PackedUserOperation calldata userOp, MemoryUserOp memory mUserOp) internal pure {
		mUserOp.sender = userOp.sender;
		mUserOp.nonce = userOp.nonce;
		(mUserOp.verificationGasLimit, mUserOp.callGasLimit) = UserOperationLib.unpackUints(userOp.accountGasLimits);
		mUserOp.preVerificationGas = userOp.preVerificationGas;
		(mUserOp.maxPriorityFeePerGas, mUserOp.maxFeePerGas) = UserOperationLib.unpackUints(userOp.gasFees);
		bytes calldata paymasterAndData = userOp.paymasterAndData;
		if (paymasterAndData.length > 0) {
			require(paymasterAndData.length >= UserOperationLib.PAYMASTER_DATA_OFFSET, "AA93 invalid paymasterAndData");
			(
				mUserOp.paymaster,
				mUserOp.paymasterVerificationGasLimit,
				mUserOp.paymasterPostOpGasLimit
			) = UserOperationLib.unpackPaymasterStaticFields(paymasterAndData);
		} else {
			mUserOp.paymaster = address(0);
			mUserOp.paymasterVerificationGasLimit = 0;
			mUserOp.paymasterPostOpGasLimit = 0;
		}
	}

	function _getRequiredPrefund(MemoryUserOp memory mUserOp) internal pure returns (uint256 requiredPrefund) {
		unchecked {
			uint256 requiredGas = mUserOp.verificationGasLimit +
				mUserOp.callGasLimit +
				mUserOp.paymasterVerificationGasLimit +
				mUserOp.paymasterPostOpGasLimit +
				mUserOp.preVerificationGas;

			requiredPrefund = requiredGas * mUserOp.maxFeePerGas;
		}
	}

	function _createSenderIfNeeded(uint256 opIndex, UserOpInfo memory opInfo, bytes calldata initCode) internal {
		if (initCode.length != 0) {
			address sender = opInfo.mUserOp.sender;
			if (sender.code.length != 0) {
				revert FailedOp(opIndex, "AA10 sender already constructed");
			}
			uint256 _creationGas = gasleft();
			address sender1 = senderCreator().createSender{gas: opInfo.mUserOp.verificationGasLimit}(initCode);
			setGasConsumed(sender, 0, _creationGas - gasleft());
			if (sender1 == address(0)) {
				revert FailedOp(opIndex, "AA13 initCode failed or OOG");
			}
			if (sender1 != sender) {
				revert FailedOp(opIndex, "AA14 initCode must return sender");
			}
			if (sender1.code.length == 0) {
				revert FailedOp(opIndex, "AA15 initCode must create sender");
			}
			address factory = address(bytes20(initCode[0:20]));
			emit AccountDeployed(opInfo.userOpHash, sender, factory, opInfo.mUserOp.paymaster);
		}
	}

	function getSenderAddress(bytes calldata initCode) public {
		address sender = senderCreator().createSender(initCode);
		revert SenderAddressResult(sender);
	}

	function _validateAccountPrepayment(
		uint256 opIndex,
		PackedUserOperation calldata op,
		UserOpInfo memory opInfo,
		uint256 requiredPrefund,
		uint256 verificationGasLimit
	) internal returns (uint256 validationData) {
		unchecked {
			MemoryUserOp memory mUserOp = opInfo.mUserOp;
			address sender = mUserOp.sender;
			_createSenderIfNeeded(opIndex, opInfo, op.initCode);
			address paymaster = mUserOp.paymaster;
			uint256 missingAccountFunds = 0;
			if (paymaster == address(0)) {
				uint256 bal = balanceOf(sender);
				missingAccountFunds = bal > requiredPrefund ? 0 : requiredPrefund - bal;
			}
			uint256 _verificationGas = gasleft();
			try
				IAccount(sender).validateUserOp{gas: verificationGasLimit}(op, opInfo.userOpHash, missingAccountFunds)
			returns (uint256 _validationData) {
				validationData = _validationData;
				setGasConsumed(sender, 1, _verificationGas - gasleft());
			} catch {
				revert FailedOpWithRevert(opIndex, "AA23 reverted", Exec.getReturnData(REVERT_REASON_MAX_LEN));
			}
			if (paymaster == address(0)) {
				DepositInfo storage senderInfo = deposits[sender];
				uint256 deposit = senderInfo.deposit;
				if (requiredPrefund > deposit) {
					revert FailedOp(opIndex, "AA21 didn't pay prefund");
				}
				senderInfo.deposit = deposit - requiredPrefund;
			}
		}
	}

	function _validatePaymasterPrepayment(
		uint256 opIndex,
		PackedUserOperation calldata op,
		UserOpInfo memory opInfo,
		uint256 requiredPreFund
	) internal returns (bytes memory context, uint256 validationData) {
		unchecked {
			uint256 preGas = gasleft();
			MemoryUserOp memory mUserOp = opInfo.mUserOp;
			address paymaster = mUserOp.paymaster;
			DepositInfo storage paymasterInfo = deposits[paymaster];
			uint256 deposit = paymasterInfo.deposit;
			if (deposit < requiredPreFund) {
				revert FailedOp(opIndex, "AA31 paymaster deposit too low");
			}
			paymasterInfo.deposit = deposit - requiredPreFund;
			uint256 pmVerificationGasLimit = mUserOp.paymasterVerificationGasLimit;
			try
				IPaymaster(paymaster).validatePaymasterUserOp{gas: pmVerificationGasLimit}(
					op,
					opInfo.userOpHash,
					requiredPreFund
				)
			returns (bytes memory _context, uint256 _validationData) {
				context = _context;
				validationData = _validationData;
			} catch {
				revert FailedOpWithRevert(opIndex, "AA33 reverted", Exec.getReturnData(REVERT_REASON_MAX_LEN));
			}
			if (preGas - gasleft() > pmVerificationGasLimit) {
				revert FailedOp(opIndex, "AA36 over paymasterVerificationGasLimit");
			}
		}
	}

	function _validateAccountAndPaymasterValidationData(
		uint256 opIndex,
		uint256 validationData,
		uint256 paymasterValidationData,
		address expectedAggregator
	) internal view {
		(address aggregator, bool outOfTimeRange) = _getValidationData(validationData);
		if (expectedAggregator != aggregator) {
			revert FailedOp(opIndex, "AA24 signature error");
		}
		if (outOfTimeRange) {
			revert FailedOp(opIndex, "AA22 expired or not due");
		}
		// pmAggregator is not a real signature aggregator: we don't have logic to handle it as address.
		// Non-zero address means that the paymaster fails due to some signature check (which is ok only during estimation).
		address pmAggregator;
		(pmAggregator, outOfTimeRange) = _getValidationData(paymasterValidationData);
		if (pmAggregator != address(0)) {
			revert FailedOp(opIndex, "AA34 signature error");
		}
		if (outOfTimeRange) {
			revert FailedOp(opIndex, "AA32 paymaster expired or not due");
		}
	}

	function _getValidationData(
		uint256 validationData
	) internal view returns (address aggregator, bool outOfTimeRange) {
		if (validationData == 0) {
			return (address(0), false);
		}
		ValidationData memory data = _parseValidationData(validationData);

		outOfTimeRange = block.timestamp > data.validUntil || block.timestamp < data.validAfter;
		aggregator = data.aggregator;
	}

	function _validatePrepayment(
		uint256 opIndex,
		PackedUserOperation calldata userOp,
		UserOpInfo memory outOpInfo
	) internal returns (uint256 validationData, uint256 paymasterValidationData) {
		uint256 preGas = gasleft();
		MemoryUserOp memory mUserOp = outOpInfo.mUserOp;
		_copyUserOpToMemory(userOp, mUserOp);
		outOpInfo.userOpHash = getUserOpHash(userOp);

		// Validate all numeric values in userOp are well below 128 bit, so they can safely be added
		// and multiplied without causing overflow.
		uint256 verificationGasLimit = mUserOp.verificationGasLimit;
		uint256 maxGasValues = mUserOp.preVerificationGas |
			verificationGasLimit |
			mUserOp.callGasLimit |
			mUserOp.paymasterVerificationGasLimit |
			mUserOp.paymasterPostOpGasLimit |
			mUserOp.maxFeePerGas |
			mUserOp.maxPriorityFeePerGas;
		require(maxGasValues <= type(uint120).max, "AA94 gas values overflow");

		uint256 requiredPreFund = _getRequiredPrefund(mUserOp);
		validationData = _validateAccountPrepayment(opIndex, userOp, outOpInfo, requiredPreFund, verificationGasLimit);

		if (!_validateAndUpdateNonce(mUserOp.sender, mUserOp.nonce)) {
			revert FailedOp(opIndex, "AA25 invalid account nonce");
		}

		unchecked {
			if (preGas - gasleft() > verificationGasLimit) {
				revert FailedOp(opIndex, "AA26 over verificationGasLimit");
			}
		}

		bytes memory context;
		if (mUserOp.paymaster != address(0)) {
			(context, paymasterValidationData) = _validatePaymasterPrepayment(
				opIndex,
				userOp,
				outOpInfo,
				requiredPreFund
			);
		}
		unchecked {
			outOpInfo.prefund = requiredPreFund;
			outOpInfo.contextOffset = getOffsetOfMemoryBytes(context);
			outOpInfo.preOpGas = preGas - gasleft() + userOp.preVerificationGas;
		}
	}

	function _postExecution(
		IPaymaster.PostOpMode mode,
		UserOpInfo memory opInfo,
		bytes memory context,
		uint256 actualGas
	) private returns (uint256 actualGasCost) {
		uint256 preGas = gasleft();
		unchecked {
			address refundAddress;
			MemoryUserOp memory mUserOp = opInfo.mUserOp;
			uint256 gasPrice = getUserOpGasPrice(mUserOp);

			address paymaster = mUserOp.paymaster;
			if (paymaster == address(0)) {
				refundAddress = mUserOp.sender;
			} else {
				refundAddress = paymaster;
				if (context.length > 0) {
					actualGasCost = actualGas * gasPrice;
					if (mode != IPaymaster.PostOpMode.postOpReverted) {
						try
							IPaymaster(paymaster).postOp{gas: mUserOp.paymasterPostOpGasLimit}(
								mode,
								context,
								actualGasCost,
								gasPrice
							)
						{} catch {
							bytes memory reason = Exec.getReturnData(REVERT_REASON_MAX_LEN);
							revert PostOpReverted(reason);
						}
					}
				}
			}
			actualGas += preGas - gasleft();

			// Calculating a penalty for unused execution gas
			{
				uint256 executionGasLimit = mUserOp.callGasLimit + mUserOp.paymasterPostOpGasLimit;
				uint256 executionGasUsed = actualGas - opInfo.preOpGas;
				// this check is required for the gas used within EntryPoint and not covered by explicit gas limits
				if (executionGasLimit > executionGasUsed) {
					uint256 unusedGas = executionGasLimit - executionGasUsed;
					uint256 unusedGasPenalty = (unusedGas * PENALTY_PERCENT) / 100;
					actualGas += unusedGasPenalty;
				}
			}

			actualGasCost = actualGas * gasPrice;
			uint256 prefund = opInfo.prefund;
			if (prefund < actualGasCost) {
				if (mode == IPaymaster.PostOpMode.postOpReverted) {
					actualGasCost = prefund;
					emitPrefundTooLow(opInfo);
					emitUserOperationEvent(opInfo, false, actualGasCost, actualGas);
				} else {
					assembly ("memory-safe") {
						mstore(0, INNER_REVERT_LOW_PREFUND)
						revert(0, 32)
					}
				}
			} else {
				uint256 refund = prefund - actualGasCost;
				_incrementDeposit(refundAddress, refund);
				bool success = mode == IPaymaster.PostOpMode.opSucceeded;
				emitUserOperationEvent(opInfo, success, actualGasCost, actualGas);
			}
		}
	}

	function getUserOpGasPrice(MemoryUserOp memory mUserOp) internal view returns (uint256) {
		unchecked {
			uint256 maxFeePerGas = mUserOp.maxFeePerGas;
			uint256 maxPriorityFeePerGas = mUserOp.maxPriorityFeePerGas;
			if (maxFeePerGas == maxPriorityFeePerGas) {
				return maxFeePerGas;
			}
			return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
		}
	}

	function getOffsetOfMemoryBytes(bytes memory data) internal pure returns (uint256 offset) {
		assembly {
			offset := data
		}
	}

	function getMemoryBytesFromOffset(uint256 offset) internal pure returns (bytes memory data) {
		assembly ("memory-safe") {
			data := offset
		}
	}

	function delegateAndRevert(address target, bytes calldata data) external {
		(bool success, bytes memory ret) = target.delegatecall(data);
		revert DelegateAndRevert(success, ret);
	}
}
