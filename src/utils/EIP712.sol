// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title EIP712
/// @dev Modified from https://github.com/Vectorized/solady/blob/main/src/utils/EIP712.sol

abstract contract EIP712 {
	/// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
	bytes32 internal constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

	bytes32 private immutable _cachedDomainSeparator;
	bytes32 private immutable _cachedNameHash;
	bytes32 private immutable _cachedVersionHash;
	uint256 private immutable _cachedChainId;
	address private immutable _cachedThis;

	constructor() {
		_cachedThis = address(this);
		_cachedChainId = block.chainid;

		if (!_domainNameAndVersionMayChange()) {
			(string memory name, string memory version) = _domainNameAndVersion();
			(_cachedNameHash, _cachedVersionHash) = (keccak256(bytes(name)), keccak256(bytes(version)));

			_cachedDomainSeparator = _buildDomainSeparator(
				_cachedNameHash,
				_cachedVersionHash,
				_cachedChainId,
				_cachedThis
			);
		}
	}

	function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

	function _domainNameAndVersionMayChange() internal pure virtual returns (bool) {}

	function eip712Domain()
		public
		view
		virtual
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainId,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		)
	{
		(name, version) = _domainNameAndVersion();
		assembly ("memory-safe") {
			fields := 0x0f
			chainId := chainid()
			verifyingContract := address()
			pop(salt)
			pop(extensions)
		}
	}

	function _domainSeparator() internal view virtual returns (bytes32 separator) {
		if (_domainNameAndVersionMayChange() || _cachedDomainSeparatorInvalidated()) {
			(string memory name, string memory version) = _domainNameAndVersion();

			separator = _buildDomainSeparator(
				keccak256(bytes(name)),
				keccak256(bytes(version)),
				block.chainid,
				address(this)
			);
		} else {
			separator = _cachedDomainSeparator;
		}
	}

	function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest) {
		digest = _domainSeparator();

		assembly ("memory-safe") {
			mstore(0x00, 0x1901000000000000)
			mstore(0x1a, digest)
			mstore(0x3a, structHash)
			digest := keccak256(0x18, 0x42)
			mstore(0x3a, 0x00)
		}
	}

	function _buildDomainSeparator(
		bytes32 nameHash,
		bytes32 versionHash,
		uint256 chainId,
		address verifyingContract
	) internal pure returns (bytes32 separator) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, DOMAIN_TYPEHASH)
			mstore(add(ptr, 0x20), nameHash)
			mstore(add(ptr, 0x40), versionHash)
			mstore(add(ptr, 0x60), chainId)
			mstore(add(ptr, 0x80), and(verifyingContract, 0xffffffffffffffffffffffffffffffffffffffff))

			separator := keccak256(ptr, 0xa0)

			mstore(ptr, 0x00)
			mstore(add(ptr, 0x20), 0x00)
			mstore(add(ptr, 0x40), 0x00)
			mstore(add(ptr, 0x60), 0x00)
			mstore(add(ptr, 0x80), 0x00)
		}
	}

	function _cachedDomainSeparatorInvalidated() private view returns (bool flag) {
		uint256 cachedChainId = _cachedChainId;
		address cachedThis = _cachedThis;
		assembly ("memory-safe") {
			flag := or(xor(chainid(), cachedChainId), xor(address(), cachedThis))
		}
	}
}
