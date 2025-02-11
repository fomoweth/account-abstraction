// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title UUPSUpgradeable
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/utils/UUPSUpgradeable.sol

abstract contract UUPSUpgradeable {
	/// @dev keccak256("Upgraded(address)")
	uint256 private constant UPGRADED_TOPIC = 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

	/// @dev uint256(keccak256("eip1967.proxy.implementation")) - 1
	bytes32 private constant ERC1967_IMPLEMENTATION_SLOT =
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	uint256 private immutable __self = uint256(uint160(address(this)));

	modifier onlyProxy() {
		uint256 self = __self;
		assembly ("memory-safe") {
			if eq(self, address()) {
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	modifier notDelegated() {
		uint256 self = __self;
		assembly ("memory-safe") {
			if xor(self, address()) {
				mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
				revert(0x1c, 0x04)
			}
		}
		_;
	}

	function proxiableUUID() public view virtual notDelegated returns (bytes32) {
		return ERC1967_IMPLEMENTATION_SLOT;
	}

	function implementation() public view virtual returns (address impl) {
		assembly ("memory-safe") {
			impl := sload(ERC1967_IMPLEMENTATION_SLOT)
		}
	}

	function upgradeToAndCall(address newImplementation, bytes calldata data) public payable virtual onlyProxy {
		_authorizeUpgrade(newImplementation);

		assembly ("memory-safe") {
			newImplementation := shr(0x60, shl(0x60, newImplementation))
			if iszero(extcodesize(newImplementation)) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			mstore(0x01, 0x52d1902d) // proxiableUUID()

			if iszero(
				eq(mload(staticcall(gas(), newImplementation, 0x1d, 0x04, 0x01, 0x20)), ERC1967_IMPLEMENTATION_SLOT)
			) {
				mstore(0x01, 0x55299b49) // UpgradeFailed()
				revert(0x1d, 0x04)
			}

			log2(codesize(), 0x00, UPGRADED_TOPIC, newImplementation)
			sstore(ERC1967_IMPLEMENTATION_SLOT, newImplementation)

			if data.length {
				let ptr := mload(0x40)
				calldatacopy(ptr, data.offset, data.length)
				if iszero(delegatecall(gas(), newImplementation, ptr, data.length, codesize(), 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function _authorizeUpgrade(address newImplementation) internal virtual;
}
