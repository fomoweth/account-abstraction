// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistryFactory} from "src/interfaces/factories/IRegistryFactory.sol";
import {IERC7484} from "src/interfaces/registries/IERC7484.sol";
import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {IVortex} from "src/interfaces/IVortex.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {ModuleType, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK, MODULE_TYPE_HOOK} from "src/types/ModuleType.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {StakingAdapter} from "src/core/StakingAdapter.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title RegistryFactory
/// @notice Manages smart account creation compliant with ERC-4337 and ERC-7579 with authorized ERC-7579 modules
contract RegistryFactory is IRegistryFactory, AccountFactory {
	using Arrays for address[];

	struct RegistryFactoryStorage {
		uint8 threshold;
		address[] attesters;
	}

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.RegistryFactory.storage.slot")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant STORAGE_SLOT = 0x304fbe580a848c6756f03436adbf800a49f9cff42738c5d8eadacdb72a5e8b00;

	uint256 private constant MAX_ATTESTERS = 32;
	uint256 private constant MAX_THRESHOLD = (1 << 8) - 1;

	/// @notice The Vortex Bootstrap contract
	IBootstrap public immutable BOOTSTRAP;

	/// @notice The ERC-7484 registry contract
	IERC7484 public immutable REGISTRY;

	constructor(
		address implementation,
		address bootstrap,
		address registry,
		address initialOwner
	) AccountFactory(implementation, initialOwner) {
		assembly ("memory-safe") {
			bootstrap := shr(0x60, shl(0x60, bootstrap))
			if iszero(bootstrap) {
				mstore(0x00, 0x5368eac9) // InvalidBootstrap()
				revert(0x1c, 0x04)
			}

			registry := shr(0x60, shl(0x60, registry))
			if iszero(registry) {
				mstore(0x00, 0x81e3306a) // InvalidERC7484Registry()
				revert(0x1c, 0x04)
			}
		}

		BOOTSTRAP = IBootstrap(bootstrap);
		REGISTRY = IERC7484(registry);
	}

	/// @inheritdoc IAccountFactory
	function createAccount(
		bytes32 salt,
		bytes calldata params
	) public payable virtual override(IAccountFactory, AccountFactory) returns (address payable account) {
		BootstrapConfig calldata rootValidator;
		BootstrapConfig[] calldata validators;
		BootstrapConfig[] calldata executors;
		BootstrapConfig[] calldata fallbacks;
		BootstrapConfig[] calldata hooks;

		assembly ("memory-safe") {
			let ptr := add(params.offset, calldataload(params.offset))
			rootValidator := ptr

			ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
			validators.offset := add(ptr, 0x20)
			validators.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x40)))
			executors.offset := add(ptr, 0x20)
			executors.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x60)))
			fallbacks.offset := add(ptr, 0x20)
			fallbacks.length := calldataload(ptr)

			ptr := add(params.offset, calldataload(add(params.offset, 0x80)))
			hooks.offset := add(ptr, 0x20)
			hooks.length := calldataload(ptr)
		}

		return createAccount(salt, rootValidator, validators, executors, fallbacks, hooks);
	}

	/// @inheritdoc IRegistryFactory
	function createAccount(
		bytes32 salt,
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks
	) public payable virtual returns (address payable account) {
		RegistryFactoryStorage storage $ = _load();
		_checkThreshold($.threshold, $.attesters.length);

		// _checkRegistry(REGISTRY, rootValidator.module, MODULE_TYPE_VALIDATOR, $.attesters, $.threshold);
		REGISTRY.check(rootValidator.module, MODULE_TYPE_VALIDATOR, $.attesters, $.threshold);
		_checkBootstrapConfigs(validators, MODULE_TYPE_VALIDATOR, $.attesters, $.threshold);
		_checkBootstrapConfigs(executors, MODULE_TYPE_EXECUTOR, $.attesters, $.threshold);
		_checkBootstrapConfigs(fallbacks, MODULE_TYPE_FALLBACK, $.attesters, $.threshold);
		_checkBootstrapConfigs(hooks, MODULE_TYPE_HOOK, $.attesters, $.threshold);

		bytes memory params = abi.encodeCall(
			IVortex.initializeAccount,
			(
				BOOTSTRAP.getInitializeCalldata(
					rootValidator,
					validators,
					executors,
					fallbacks,
					hooks,
					address(REGISTRY),
					$.attesters,
					$.threshold
				)
			)
		);

		return _createAccount(ACCOUNT_IMPLEMENTATION, salt, params);
	}

	/// @inheritdoc IRegistryFactory
	function configure(address[] calldata attesters, uint8 threshold) external payable onlyOwner {
		uint256 attestersLength = attesters.length;
		require(attestersLength <= MAX_ATTESTERS, ExceededMaxAttesters());

		attesters.insertionSort();
		attesters.uniquifySorted();

		_checkAttesters(attesters, attestersLength);
		_checkThreshold(threshold, attestersLength);

		RegistryFactoryStorage storage $ = _load();
		$.attesters = attesters;
		$.threshold = threshold;
	}

	/// @inheritdoc IRegistryFactory
	function authorize(address attester) external payable onlyOwner {
		require(attester != address(0), InvalidAttesters());

		RegistryFactoryStorage storage $ = _load();

		address[] memory attesters = $.attesters.copy();
		require(!attesters.inSorted(attester), AttesterAlreadyExists(attester));

		uint256 attestersLength = attesters.length + 1;
		require(attestersLength <= MAX_ATTESTERS, ExceededMaxAttesters());

		$.attesters.push(attester);
		attesters = $.attesters.copy();

		attesters.insertionSort();
		attesters.uniquifySorted();

		_checkAttesters(attesters, attestersLength);
		_checkThreshold($.threshold, attestersLength);

		$.attesters = attesters;
	}

	/// @inheritdoc IRegistryFactory
	function revoke(address attester) external payable onlyOwner {
		require(attester != address(0), InvalidAttesters());

		RegistryFactoryStorage storage $ = _load();

		address[] memory attesters = $.attesters.copy();
		(bool exists, uint256 index) = attesters.searchSorted(attester);
		require(exists, AttesterNotExists(attester));

		uint256 attestersLength = attesters.length - 1;
		attesters[index] = attesters[attestersLength];

		assembly ("memory-safe") {
			mstore(attesters, attestersLength)
		}

		attesters.insertionSort();
		attesters.uniquifySorted();

		_checkAttesters(attesters, attestersLength);
		_checkThreshold($.threshold, attestersLength);

		$.attesters = attesters;
	}

	/// @inheritdoc IRegistryFactory
	function setThreshold(uint8 threshold) external payable onlyOwner {
		RegistryFactoryStorage storage $ = _load();
		_checkThreshold(threshold, $.attesters.length);
		$.threshold = threshold;
	}

	/// @inheritdoc IRegistryFactory
	function isAuthorized(address attester) external view returns (bool) {
		return _load().attesters.inSorted(attester);
	}

	/// @inheritdoc IRegistryFactory
	function getAttesters() external view returns (address[] memory attesters) {
		return _load().attesters;
	}

	/// @inheritdoc IRegistryFactory
	function getThreshold() external view returns (uint8) {
		return _load().threshold;
	}

	/// @inheritdoc IAccountFactory
	function name() public pure virtual override(IAccountFactory, AccountFactory) returns (string memory) {
		return "RegistryFactory";
	}

	/// @inheritdoc IAccountFactory
	function version() public pure virtual override(IAccountFactory, AccountFactory) returns (string memory) {
		return "1.0.0";
	}

	function _checkBootstrapConfigs(
		BootstrapConfig[] calldata configs,
		ModuleType moduleTypeId,
		address[] memory attesters,
		uint256 threshold
	) internal view virtual {
		uint256 length = configs.length;
		for (uint256 i; i < length; ) {
			// _checkRegistry(REGISTRY, configs[i].module, moduleTypeId, attesters, threshold);
			REGISTRY.check(configs[i].module, moduleTypeId, attesters, threshold);

			unchecked {
				i = i + 1;
			}
		}
	}

	function _checkRegistry(
		address registry,
		address module,
		ModuleType moduleTypeId,
		address[] memory attesters,
		uint256 threshold
	) internal view virtual {
		assembly ("memory-safe") {
			if iszero(shl(0x60, module)) {
				mstore(0x00, 0xdd914b28) // InvalidModule()
				revert(0x1c, 0x04)
			}

			let length := mload(attesters)
			let offset := add(attesters, 0x20)
			let ptr := mload(0x40)

			mstore(ptr, 0x2ed9446700000000000000000000000000000000000000000000000000000000) // check(address,uint256,address[],uint256)
			mstore(add(ptr, 0x04), shr(0x60, shl(0x60, module)))
			mstore(add(ptr, 0x24), moduleTypeId)
			mstore(add(ptr, 0x44), 0x80)
			mstore(add(ptr, 0x64), and(threshold, 0xff))
			mstore(add(ptr, 0x84), length)

			// prettier-ignore
			for { let i } lt(i, length) { i := add(i, 0x01) } {
				mstore(add(add(ptr, 0xa4), shl(0x05, i)), mload(add(offset, shl(0x05, i))))
			}

			mstore(0x40, and(add(add(add(ptr, 0xa4), shl(0x05, length)), 0x1f), not(0x1f)))

			if iszero(staticcall(gas(), registry, ptr, add(shl(0x05, length), 0xa4), 0x00, 0x00)) {
				mstore(0x00, 0x4860061a) // ModuleNotAuthorized(address)
				mstore(0x20, shr(0x60, shl(0x60, module)))
				revert(0x1c, 0x44)
			}
		}
	}

	function _checkAttestations(
		address[] memory attesters,
		uint256 attestersLength,
		uint8 threshold
	) internal pure virtual {
		require(attestersLength <= MAX_ATTESTERS, ExceededMaxAttesters());
		_checkAttesters(attesters, attestersLength);
		_checkThreshold(threshold, attestersLength);
	}

	function _checkAttesters(address[] memory attesters, uint256 attestersLength) internal pure virtual {
		require(attestersLength == attesters.length && attesters[0] != address(0), InvalidAttesters());
	}

	function _checkThreshold(uint8 threshold, uint256 attestersLength) internal pure virtual {
		require(threshold != 0 && threshold <= attestersLength, InvalidThreshold());
	}

	function _load() internal pure virtual returns (RegistryFactoryStorage storage $) {
		assembly ("memory-safe") {
			$.slot := STORAGE_SLOT
		}
	}
}
