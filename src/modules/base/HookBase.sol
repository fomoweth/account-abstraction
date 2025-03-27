// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHook} from "src/interfaces/IERC7579Modules.sol";
import {TrustedForwarder} from "src/modules/utils/TrustedForwarder.sol";
import {ModuleBase} from "./ModuleBase.sol";

/// @title HookBase

abstract contract HookBase is IHook, ModuleBase, TrustedForwarder {
	function preCheck(
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) external payable virtual returns (bytes memory hookData) {
		return _preCheck(_mapAccount(), msgSender, msgValue, msgData);
	}

	function postCheck(bytes calldata hookData) external payable virtual {
		_postCheck(_mapAccount(), hookData);
	}

	function _preCheck(
		address account,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual returns (bytes memory hookData);

	function _postCheck(address account, bytes calldata hookData) internal virtual;
}
