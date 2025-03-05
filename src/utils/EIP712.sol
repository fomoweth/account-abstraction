// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title EIP712
/// @dev Modified from https://github.com/Vectorized/solady/blob/main/src/utils/EIP712.sol

abstract contract EIP712 {
	/// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
	bytes32 internal constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

	/// @dev keccak256("EIP712Domain(string name,string version,address verifyingContract)")
	bytes32 internal constant DOMAIN_TYPEHASH_SANS_CHAIN_ID =
		0x91ab3d17e3a50a9d89e63fd30b92be7f5336b03b287bb946787a83a9d62a2766;

	bytes32 private immutable _cachedDomainSeparator;
	bytes32 private immutable _cachedNameHash;
	bytes32 private immutable _cachedVersionHash;
	uint256 private immutable _cachedChainId;
	uint256 private immutable _cachedThis;

	constructor() {
		(string memory name, string memory version) = _domainNameAndVersion();
		_cachedThis = uint256(uint160(address(this)));
		_cachedChainId = block.chainid;
		_cachedDomainSeparator = _buildDomainSeparator(
			(_cachedNameHash = _hash(bytes(name))),
			(_cachedVersionHash = _hash(bytes(version)))
		);
	}

	function DOMAIN_SEPARATOR() external view returns (bytes32) {
		return _domainSeparator();
	}

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

	function hashTypedData(bytes32 structHash) public view virtual returns (bytes32 digest) {
		digest = _domainSeparator();
		assembly ("memory-safe") {
			mstore(0x00, 0x1901000000000000)
			mstore(0x1a, digest)
			mstore(0x3a, structHash)
			digest := keccak256(0x18, 0x42)
			mstore(0x3a, 0x00)
		}
	}

	function hashTypedDataSansChainId(bytes32 structHash) public view virtual returns (bytes32 digest) {
		(string memory name, string memory version) = _domainNameAndVersion();
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(0x00, DOMAIN_TYPEHASH_SANS_CHAIN_ID)
			mstore(0x20, keccak256(add(name, 0x20), mload(name)))
			mstore(0x40, keccak256(add(version, 0x20), mload(version)))
			mstore(0x60, address())
			mstore(0x20, keccak256(0x00, 0x80))
			mstore(0x00, 0x1901)
			mstore(0x40, structHash)
			digest := keccak256(0x1e, 0x42)
			mstore(0x40, ptr)
			mstore(0x60, 0x00)
		}
	}

	function _domainSeparator() internal view virtual returns (bytes32) {
		if (!_cachedDomainSeparatorInvalidated()) return _cachedDomainSeparator;

		(string memory name, string memory version) = _domainNameAndVersion();
		return _buildDomainSeparator(_hash(bytes(name)), _hash(bytes(version)));
	}

	function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

	function _buildDomainSeparator(bytes32 nameHash, bytes32 versionHash) private view returns (bytes32 separator) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			mstore(ptr, DOMAIN_TYPEHASH)
			mstore(add(ptr, 0x20), nameHash)
			mstore(add(ptr, 0x40), versionHash)
			mstore(add(ptr, 0x60), chainid())
			mstore(add(ptr, 0x80), address())
			separator := keccak256(ptr, 0xa0)
		}
	}

	function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
		uint256 cachedChainId = _cachedChainId;
		uint256 cachedThis = _cachedThis;
		assembly ("memory-safe") {
			result := or(xor(chainid(), cachedChainId), xor(address(), cachedThis))
		}
	}

	function _hash(bytes memory data) internal pure virtual returns (bytes32 digest) {
		assembly ("memory-safe") {
			digest := keccak256(add(data, 0x20), mload(data))
		}
	}
}
