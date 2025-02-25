// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title TrustedForwarder

abstract contract TrustedForwarder {
	/// @dev keccak256("TrustedForwarderConfigured(address,address)")
	bytes32 private constant TRUSTED_FORWARDER_CONFIGURED_TOPIC =
		0x429e8cf7466d66b9f6a361e25bf9ce5418c81055846e5b716e5ab2fae2611d95;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.module.trustedForwarders")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant TRUSTED_FORWARDERS_SLOT =
		0x0bbe1ebe3453361add0e00d1239aa291b315d54a2a4ce1b8c20d3c415bb3e300;

	function setTrustedForwarder(address forwarder) external {
		_setTrustedForwarder(forwarder);
	}

	function clearTrustedForwarder() public {
		_setTrustedForwarder(address(0));
	}

	function getTrustedForwarder(address account) public view virtual returns (address forwarder) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, account)))
			mstore(0x20, TRUSTED_FORWARDERS_SLOT)
			forwarder := sload(keccak256(0x00, 0x40))
		}
	}

	function isTrustedForwarder(address account, address forwarder) public view virtual returns (bool result) {
		return forwarder == getTrustedForwarder(account);
	}

	function _setTrustedForwarder(address forwarder) internal virtual {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))
			mstore(0x20, TRUSTED_FORWARDERS_SLOT)
			sstore(keccak256(0x00, 0x40), shr(0x60, shl(0x60, forwarder)))
			log3(0x00, 0x00, TRUSTED_FORWARDER_CONFIGURED_TOPIC, caller(), forwarder)
		}
	}

	function _mapAccount() internal view virtual returns (address account) {
		assembly ("memory-safe") {
			account := caller()
			let calldataSize := calldatasize()
			if iszero(lt(calldataSize, 0x28)) {
				let forwarder := shr(0x60, calldataload(sub(calldataSize, 0x28)))
				if eq(forwarder, caller()) {
					mstore(0x00, shr(0x60, calldataload(sub(calldataSize, 0x14))))
					mstore(0x20, TRUSTED_FORWARDERS_SLOT)

					if eq(forwarder, sload(keccak256(0x00, 0x40))) {
						account := shr(0x60, calldataload(sub(calldataSize, 0x14)))
					}
				}
			}
		}
	}
}
