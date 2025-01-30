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
	uint256 private immutable _cachedThis;

	constructor() {
		(string memory name, string memory version) = _domainNameAndVersion();
		_cachedNameHash = memoryKeccak256(bytes(name));
		_cachedVersionHash = memoryKeccak256(bytes(version));

		_cachedThis = uint256(uint160(address(this)));
		_cachedChainId = block.chainid;
		_cachedDomainSeparator = _buildDomainSeparator(
			_cachedNameHash,
			_cachedVersionHash,
			_cachedChainId,
			address(this)
		);
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

	function _domainSeparator() internal view virtual returns (bytes32 separator) {
		if (!_cachedDomainSeparatorInvalidated()) return _cachedDomainSeparator;

		(string memory name, string memory version) = _domainNameAndVersion();

		separator = _buildDomainSeparator(
			memoryKeccak256(bytes(name)),
			memoryKeccak256(bytes(version)),
			block.chainid,
			address(this)
		);
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
			mstore(add(ptr, 0x80), shr(0x60, shl(0x60, verifyingContract)))
			separator := keccak256(ptr, 0xa0)
		}
	}

	function memoryKeccak256(bytes memory data) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			digest := keccak256(add(data, 0x20), mload(data))
		}
	}

	function _cachedDomainSeparatorInvalidated() private view returns (bool flag) {
		uint256 cachedChainId = _cachedChainId;
		uint256 cachedThis = _cachedThis;
		assembly ("memory-safe") {
			flag := or(xor(chainid(), cachedChainId), xor(address(), cachedThis))
		}
	}

	function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);
}
