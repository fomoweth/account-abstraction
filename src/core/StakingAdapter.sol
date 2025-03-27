// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStakingAdapter} from "src/interfaces/IStakingAdapter.sol";
import {Ownable} from "src/utils/Ownable.sol";

/// @title StakingAdapter
/// @notice Provides an interface for managing deposits and stakes on EntryPoint

contract StakingAdapter is IStakingAdapter, Ownable {
	constructor(address initialOwner) {
		_initializeOwner(initialOwner);
	}

	function balanceOf(address ep, address account) public view virtual returns (uint256 deposit) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000) // balanceOf(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, account)))

			deposit := mul(mload(0x00), and(gt(returndatasize(), 0x1f), staticcall(gas(), ep, ptr, 0x24, 0x00, 0x20)))
		}
	}

	function getDepositInfo(
		address ep,
		address account
	)
		public
		view
		virtual
		returns (uint256 deposit, bool staked, uint112 stake, uint32 unstakeDelaySec, uint48 withdrawTime)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5287ce1200000000000000000000000000000000000000000000000000000000) // getDepositInfo(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, account)))

			if iszero(staticcall(gas(), ep, ptr, 0x24, add(ptr, 0x24), 0xa0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			deposit := mload(add(ptr, 0x24))
			staked := and(mload(add(ptr, 0x44)), 0xff)
			stake := and(mload(add(ptr, 0x64)), 0xffffffffffffffffffffffffff)
			unstakeDelaySec := and(mload(add(ptr, 0x84)), 0xffffffff)
			withdrawTime := and(mload(add(ptr, 0xa4)), 0xffffffffffff)
		}
	}

	function depositTo(address ep, address recipient) external payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xb760faf900000000000000000000000000000000000000000000000000000000) // depositTo(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))

			if iszero(mul(extcodesize(ep), call(gas(), ep, callvalue(), ptr, 0x24, 0x00, 0x00))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function withdrawTo(address ep, address recipient, uint256 amount) external payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x205c287800000000000000000000000000000000000000000000000000000000) // withdrawTo(address,uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))
			mstore(add(ptr, 0x24), amount)

			if iszero(mul(extcodesize(ep), call(gas(), ep, 0x00, ptr, 0x44, 0x00, 0x00))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function addStake(address ep, uint32 unstakeDelaySec) external payable virtual onlyOwner {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x0396cb6000000000000000000000000000000000000000000000000000000000) // addStake(uint32)
			mstore(add(ptr, 0x04), and(unstakeDelaySec, 0xffffffff))

			if iszero(mul(extcodesize(ep), call(gas(), ep, callvalue(), ptr, 0x24, 0x00, 0x00))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unlockStake(address ep) external payable virtual onlyOwner {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xbb9fe6bf00000000000000000000000000000000000000000000000000000000) // unlockStake()

			if iszero(mul(extcodesize(ep), call(gas(), ep, 0x00, ptr, 0x04, 0x00, 0x00))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function withdrawStake(address ep, address recipient) external payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(shl(0x60, recipient)) {
				mstore(0x00, 0x9c8d2cd2) // InvalidRecipient()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0xc23a5cea00000000000000000000000000000000000000000000000000000000) // withdrawStake(address)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, recipient)))

			if iszero(mul(extcodesize(ep), call(gas(), ep, 0x00, ptr, 0x24, 0x00, 0x00))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	receive() external payable virtual {}
}
