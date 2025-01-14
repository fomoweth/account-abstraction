// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Currency} from "src/types/Currency.sol";

/// @title CurrencyNamer
/// @dev Modified from https://github.com/Uniswap/v3-periphery/blob/0.8/contracts/libraries/SafeERC20Namer.sol

library CurrencyNamer {
	bytes4 private constant SYMBOL_SELECTOR = 0x95d89b41;
	bytes4 private constant NAME_SELECTOR = 0x06fdde03;

	function symbol(Currency currency) internal view returns (string memory) {
		string memory res = callAndParseStringReturn(currency, SYMBOL_SELECTOR);

		if (bytes(res).length == 0) {
			return Strings.toHexString(uint256(uint160(Currency.unwrap(currency))), 4);
		}

		return res;
	}

	function name(Currency currency) internal view returns (string memory) {
		string memory res = callAndParseStringReturn(currency, NAME_SELECTOR);

		if (bytes(res).length == 0) {
			return Strings.toHexString(Currency.unwrap(currency));
		}

		return res;
	}

	function callAndParseStringReturn(Currency currency, bytes4 selector) private view returns (string memory) {
		(bool success, bytes memory returndata) = Currency.unwrap(currency).staticcall(
			abi.encodeWithSelector(selector)
		);

		if (success && returndata.length != 0) {
			if (returndata.length == 32) {
				return bytes32ToString(abi.decode(returndata, (bytes32)));
			} else if (returndata.length > 64) {
				return abi.decode(returndata, (string));
			}
		}

		return "";
	}

	function bytes32ToString(bytes32 target) internal pure returns (string memory) {
		bytes memory buffer = new bytes(32);
		uint8 count;

		unchecked {
			for (uint8 i; i < 32; ++i) {
				bytes1 char = target[i];

				if (char != 0) {
					buffer[count] = char;
					++count;
				}
			}
		}

		bytes memory trimmed = new bytes(count);

		unchecked {
			for (uint8 i; i < count; ++i) {
				trimmed[i] = buffer[i];
			}
		}

		return string(trimmed);
	}
}
