// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {strings} from "string-utils/strings.sol";

/// @title AccountIdLib
/// @notice Provides function for parsing the full account name and version

library AccountIdLib {
	using strings for *;

	function parse(string memory accountId) internal pure returns (string memory name, string memory version) {
		strings.slice memory id = accountId.toSlice();
		strings.slice memory delim = ".".toSlice();

		name = string.concat(id.split(delim).toString(), " ", id.split(delim).toString());
		version = id.toString();
	}
}
