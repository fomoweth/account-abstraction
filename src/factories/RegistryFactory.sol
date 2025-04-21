// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistryFactory} from "src/interfaces/factories/IRegistryFactory.sol";
import {IERC7484} from "src/interfaces/registries/IERC7484.sol";
import {IBootstrap, BootstrapConfig} from "src/interfaces/IBootstrap.sol";
import {IVortex} from "src/interfaces/IVortex.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {ModuleType} from "src/types/ModuleType.sol";
import {IAccountFactory, AccountFactory} from "./AccountFactory.sol";

/// @title RegistryFactory
/// @notice Manages smart account creation compliant with ERC-4337 and ERC-7579 with authorized ERC-7579 modules
contract RegistryFactory is IRegistryFactory, AccountFactory {
	using Arrays for address[];

	struct AttestationStorage {
		uint8 threshold;
		address[] attesters;
	}

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.factory.storage.attestations")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant STORAGE_NAMESPACE = 0xb3465a40b5a117167923395735af80fbe5f232a4e9b1a720b24f97436b58b800;

	ModuleType private constant MODULE_TYPE_VALIDATOR = ModuleType.wrap(0x01);
	ModuleType private constant MODULE_TYPE_EXECUTOR = ModuleType.wrap(0x02);
	ModuleType private constant MODULE_TYPE_FALLBACK = ModuleType.wrap(0x03);
	ModuleType private constant MODULE_TYPE_HOOK = ModuleType.wrap(0x04);
	ModuleType private constant MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 = ModuleType.wrap(0x08);
	ModuleType private constant MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 = ModuleType.wrap(0x09);

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
		BootstrapConfig calldata preValidationHook1271;
		BootstrapConfig calldata preValidationHook4337;

		assembly ("memory-safe") {
			rootValidator := add(params.offset, calldataload(params.offset))

			let ptr := add(params.offset, calldataload(add(params.offset, 0x20)))
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

			preValidationHook1271 := add(params.offset, calldataload(add(params.offset, 0xa0)))
			preValidationHook4337 := add(params.offset, calldataload(add(params.offset, 0xc0)))
		}

		account = createAccount(
			salt,
			rootValidator,
			validators,
			executors,
			fallbacks,
			hooks,
			preValidationHook1271,
			preValidationHook4337
		);
	}

	/// @inheritdoc IRegistryFactory
	function createAccount(
		bytes32 salt,
		BootstrapConfig calldata rootValidator,
		BootstrapConfig[] calldata validators,
		BootstrapConfig[] calldata executors,
		BootstrapConfig[] calldata fallbacks,
		BootstrapConfig[] calldata hooks,
		BootstrapConfig calldata preValidationHook1271,
		BootstrapConfig calldata preValidationHook4337
	) public payable virtual returns (address payable account) {
		AttestationStorage storage $ = _getAttestationStorage();
		_validateThreshold($.threshold, $.attesters.length);

		REGISTRY.check(rootValidator.module, MODULE_TYPE_VALIDATOR, $.attesters, $.threshold);

		_checkBootstrapConfigs(validators, MODULE_TYPE_VALIDATOR, $.attesters, $.threshold);
		_checkBootstrapConfigs(executors, MODULE_TYPE_EXECUTOR, $.attesters, $.threshold);
		_checkBootstrapConfigs(fallbacks, MODULE_TYPE_FALLBACK, $.attesters, $.threshold);
		_checkBootstrapConfigs(hooks, MODULE_TYPE_HOOK, $.attesters, $.threshold);

		if (preValidationHook1271.module != address(0)) {
			REGISTRY.check(
				preValidationHook1271.module,
				MODULE_TYPE_PREVALIDATION_HOOK_ERC1271,
				$.attesters,
				$.threshold
			);
		}

		if (preValidationHook4337.module != address(0)) {
			REGISTRY.check(
				preValidationHook4337.module,
				MODULE_TYPE_PREVALIDATION_HOOK_ERC4337,
				$.attesters,
				$.threshold
			);
		}

		bytes memory params = abi.encodeCall(
			IVortex.initializeAccount,
			(
				BOOTSTRAP.getInitializeCalldata(
					rootValidator,
					validators,
					executors,
					fallbacks,
					hooks,
					preValidationHook1271,
					preValidationHook4337,
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

		_validateAttesters(attesters, attestersLength);
		_validateThreshold(threshold, attestersLength);

		AttestationStorage storage $ = _getAttestationStorage();
		$.attesters = attesters;
		$.threshold = threshold;
	}

	/// @inheritdoc IRegistryFactory
	function authorize(address attester) external payable onlyOwner {
		require(attester != address(0), InvalidAttester());

		AttestationStorage storage $ = _getAttestationStorage();

		address[] memory attesters = $.attesters.copy();
		require(!attesters.inSorted(attester), AttesterAlreadyExists(attester));

		uint256 attestersLength = attesters.length + 1;
		require(attestersLength <= MAX_ATTESTERS, ExceededMaxAttesters());

		$.attesters.push(attester);
		attesters = $.attesters.copy();

		attesters.insertionSort();
		attesters.uniquifySorted();

		_validateAttesters(attesters, attestersLength);
		_validateThreshold($.threshold, attestersLength);

		$.attesters = attesters;
	}

	/// @inheritdoc IRegistryFactory
	function revoke(address attester) external payable onlyOwner {
		require(attester != address(0), InvalidAttester());

		AttestationStorage storage $ = _getAttestationStorage();

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

		_validateAttesters(attesters, attestersLength);
		_validateThreshold($.threshold, attestersLength);

		$.attesters = attesters;
	}

	/// @inheritdoc IRegistryFactory
	function setThreshold(uint8 threshold) external payable onlyOwner {
		AttestationStorage storage $ = _getAttestationStorage();
		_validateThreshold(threshold, $.attesters.length);
		$.threshold = threshold;
	}

	/// @inheritdoc IRegistryFactory
	function isAuthorized(address attester) external view returns (bool) {
		return _getAttestationStorage().attesters.inSorted(attester);
	}

	/// @inheritdoc IRegistryFactory
	function getTrustedAttesters() external view returns (address[] memory attesters) {
		return _getAttestationStorage().attesters;
	}

	/// @inheritdoc IRegistryFactory
	function getThreshold() external view returns (uint8) {
		return _getAttestationStorage().threshold;
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
			REGISTRY.check(configs[i].module, moduleTypeId, attesters, threshold);

			unchecked {
				i = i + 1;
			}
		}
	}

	function _validateAttestations(
		address[] memory attesters,
		uint256 attestersLength,
		uint8 threshold
	) internal pure virtual {
		require(attestersLength <= MAX_ATTESTERS, ExceededMaxAttesters());
		_validateAttesters(attesters, attestersLength);
		_validateThreshold(threshold, attestersLength);
	}

	function _validateAttesters(address[] memory attesters, uint256 attestersLength) internal pure virtual {
		require(attestersLength == attesters.length && attesters[0] != address(0), InvalidTrustedAttesters());
	}

	function _validateThreshold(uint8 threshold, uint256 attestersLength) internal pure virtual {
		require(threshold != 0 && threshold <= attestersLength, InvalidThreshold());
	}

	function _getAttestationStorage() internal pure virtual returns (AttestationStorage storage $) {
		assembly ("memory-safe") {
			$.slot := STORAGE_NAMESPACE
		}
	}
}
