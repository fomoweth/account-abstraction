// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {strings} from "string-utils/strings.sol";

/// @title AccountIdLib
/// @notice Provides function for parsing the full account name and version.
library AccountIdLib {
	using strings for *;

	/// @notice Returns the account name and version as strings
	/// @param accountId Structured ID in the format "vendorname.accountname.semver"
	/// @return name The account name of the smart account
	/// @return version The version of the smart account
	function parse(string memory accountId) internal pure returns (string memory name, string memory version) {
		strings.slice memory id = accountId.toSlice();
		strings.slice memory delim = ".".toSlice();

		id.split(delim); // vendorname
		name = _capitalize(id.split(delim));
		version = id.toString();
	}

	function _capitalize(strings.slice memory slice) private pure returns (string memory) {
		bytes memory buffer = bytes(slice.toString());
		bytes1 char = buffer[0];
		if (char >= 0x61 && char <= 0x7A) {
			buffer[0] = bytes1(uint8(char) - 32);
		}

		return string(buffer);
	}
}
