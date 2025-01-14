// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {strings} from "stringutils/strings.sol";

/// @title AccountIdLib

library AccountIdLib {
	using strings for *;

	function parseAccountId(string memory accountId) internal pure returns (string memory name, string memory version) {
		strings.slice memory id = accountId.toSlice();
		strings.slice memory delim = ".".toSlice();

		name = string(abi.encodePacked(id.split(delim).toString(), " ", id.split(delim).toString()));
		version = id.toString();
	}
}
