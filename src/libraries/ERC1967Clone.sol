// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ERC1967Clone
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol

library ERC1967Clone {
	function createDeterministic(
		address implementation,
		bytes32 salt
	) internal returns (bool alreadyDeployed, address instance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
			mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
			mstore(0x20, 0x6009)
			mstore(0x1e, implementation)
			mstore(0x0a, 0x603d3d8160223d3973)

			mstore(add(ptr, 0x35), keccak256(0x21, 0x5f))
			mstore(ptr, shl(0x58, address()))
			mstore8(ptr, 0xff)
			mstore(add(ptr, 0x15), salt)

			instance := keccak256(ptr, 0x55)

			// prettier-ignore
			for { } 0x01 { } {
				if iszero(extcodesize(instance)) {
					instance := create2(callvalue(), 0x21, 0x5f, salt)

					if iszero(instance) {
						mstore(0x00, 0x30116425) // DeploymentFailed()
						revert(0x1c, 0x04)
					}

					break
				}

				alreadyDeployed := 0x01

				if iszero(callvalue()) { break }
				if iszero(call(gas(), instance, callvalue(), codesize(), 0x00, codesize(), 0x00)) {
					mstore(0x00, 0xb12d13eb) // ETHTransferFailed()
					revert(0x1c, 0x04)
				}

				break
			}

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}

	function predictDeterministicAddress(
		address implementation,
		bytes32 salt
	) internal view returns (address predicted) {
		return predictDeterministicAddress(initCodeHash(implementation), salt);
	}

	function predictDeterministicAddress(bytes32 hash, bytes32 salt) internal view returns (address predicted) {
		assembly ("memory-safe") {
			mstore8(0x00, 0xff)
			mstore(0x35, hash)
			mstore(0x01, shl(0x60, address()))
			mstore(0x15, salt)

			predicted := keccak256(0x00, 0x55)

			mstore(0x35, 0x00)
		}
	}

	function initCodeHash(address implementation) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
			mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
			mstore(0x20, 0x6009)
			mstore(0x1e, implementation)
			mstore(0x0a, 0x603d3d8160223d3973)

			digest := keccak256(0x21, 0x5f)

			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}

	function initCode(address implementation) internal pure returns (bytes memory ret) {
		assembly ("memory-safe") {
			ret := mload(0x40)

			mstore(add(ret, 0x60), 0x3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f300)
			mstore(add(ret, 0x40), 0x55f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc)
			mstore(add(ret, 0x20), or(shl(0x18, implementation), 0x600951))
			mstore(add(ret, 0x09), 0x603d3d8160223d3973)
			mstore(ret, 0x5f)
			mstore(0x40, add(ret, 0x80))
		}
	}
}
