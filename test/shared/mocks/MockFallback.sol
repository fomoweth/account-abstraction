// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType} from "src/types/Types.sol";
import {FallbackBase} from "src/modules/base/FallbackBase.sol";

contract MockFallback is FallbackBase {
	event FallbackCall(address indexed sender, bytes32 indexed value);
	event FallbackDelegate(address indexed sender, bytes32 indexed value);

	error InvalidFallback();

	mapping(address account => bool isInstalled) internal _isInstalled;
	mapping(address account => bytes32 data) internal _accountData;

	address public immutable self = address(this);

	function onInstall(bytes calldata) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function fallbackSingle(bytes32 value) public payable virtual {
		require(address(this) == self, InvalidFallback());
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));

		_accountData[msg.sender] = value;

		emit FallbackCall(_msgSender(), value);
	}

	function fallbackDelegate(bytes32 value) public payable virtual {
		require(address(this) != self, InvalidFallback());

		emit FallbackDelegate(_msgSender(), value);
	}

	function fallbackStatic(address account) public view virtual returns (bytes32) {
		return _accountData[account];
	}

	function fallbackSuccess() external pure returns (bytes32) {
		return keccak256("SUCCESS");
	}

	function fallbackRevert() external pure {
		revert("REVERT");
	}

	function name() external pure returns (string memory) {
		return "MockFallback";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_FALLBACK;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _isInstalled[account];
	}
}
