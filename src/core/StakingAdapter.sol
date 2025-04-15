// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStakingAdapter} from "src/interfaces/IStakingAdapter.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title StakingAdapter
/// @notice Provides an interface for managing ETH deposit and stake on EntryPoint
contract StakingAdapter is IStakingAdapter, Ownable {
	uint112 internal constant MAX_STAKE = (1 << 112) - 1;
	uint112 internal constant MIN_STAKE = 0.5 ether;

	uint32 internal constant MIN_UNSTAKE_DELAY = 1 weeks;

	constructor(address initialOwner) {
		_initializeOwner(initialOwner);
	}

	/// @inheritdoc IStakingAdapter
	function deposit(address entryPoint) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if iszero(callvalue()) {
				mstore(0x00, 0xfe9ba5cd) // InvalidDepositAmount()
				revert(0x1c, 0x04)
			}

			if iszero(call(gas(), entryPoint, callvalue(), codesize(), 0x00, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	/// @inheritdoc IStakingAdapter
	function withdraw(address entryPoint, address recipient, uint256 amount) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			if iszero(amount) {
				mstore(0x00, 0xdb73cdf0) // InvalidWithdrawAmount()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x205c287800000000000000000000000000000000000000000000000000000000) // withdrawTo(address,uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), entryPoint, 0x00, ptr, 0x44, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @inheritdoc IStakingAdapter
	function stake(address entryPoint, uint32 unstakeDelaySec) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if lt(unstakeDelaySec, MIN_UNSTAKE_DELAY) {
				mstore(0x00, 0x4d2793aa) // InvalidUnstakeDelaySec()
				revert(0x1c, 0x04)
			}

			if or(lt(callvalue(), MIN_STAKE), gt(callvalue(), MAX_STAKE)) {
				mstore(0x00, 0x040ef8ec) // InvalidStakeAmount()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x0396cb6000000000000000000000000000000000000000000000000000000000) // addStake(uint32)
			mstore(add(ptr, 0x04), unstakeDelaySec)

			if iszero(call(gas(), entryPoint, callvalue(), ptr, 0x24, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @inheritdoc IStakingAdapter
	function unlock(address entryPoint) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			mstore(0x00, 0xbb9fe6bf) // unlockStake()

			if iszero(call(gas(), entryPoint, 0x00, 0x1c, 0x04, codesize(), 0x00)) {
				let ptr := mload(0x40)
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @inheritdoc IStakingAdapter
	function unstake(address entryPoint, address recipient) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xc23a5cea00000000000000000000000000000000000000000000000000000000) // withdrawStake(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))

			if iszero(call(gas(), entryPoint, 0x00, ptr, 0x24, codesize(), 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	/// @inheritdoc IStakingAdapter
	function balanceOf(address entryPoint, address entity) public view virtual returns (uint256 value) {
		assembly ("memory-safe") {
			if iszero(shl(0x60, entryPoint)) {
				mstore(0x00, 0x2039d3c9) // InvalidEntryPoint()
				revert(0x1c, 0x04)
			}

			if iszero(shl(0x60, entity)) {
				mstore(0x00, 0x4b4cb7dd) // InvalidEntity()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000) // balanceOf(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, entity)))

			// prettier-ignore
			value := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), entryPoint, ptr, 0x24, 0x00, 0x20)))
		}
	}
}
