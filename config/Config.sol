// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "lib/forge-std/src/StdJson.sol";
import {Currency} from "src/types/Currency.sol";
import {AaveV3Config, UniswapConfig} from "test/shared/structs/Protocols.sol";

using ConfigLibrary for Config global;

struct Config {
	string json;
}

library ConfigLibrary {
	using stdJson for string;

	/// https://crates.io/crates/jsonpath-rust

	string internal constant WRAPPED_NATIVE_PATH = "$.wrappedNative";
	string internal constant AAVE_V3_PATH = "$.aave-v3";
	string internal constant UNISWAP_PATH = "$.uniswap";

	function loadAddress(Config storage config, string memory key) internal view returns (address) {
		return config.json.readAddressOr(string.concat("$.", key), address(0));
	}

	function loadAddressArray(Config storage config, string memory key) internal view returns (address[] memory) {
		return config.json.readAddressArrayOr(string.concat("$.", key), new address[](0));
	}

	function loadAddressArray(
		Config storage config,
		string[] memory keys
	) internal view returns (address[] memory addresses) {
		uint256 length = keys.length;
		uint256 count;
		address target;

		addresses = new address[](length);

		for (uint256 i; i < length; ++i) {
			if ((target = loadAddress(config, keys[i])) != address(0)) {
				addresses[i] = target;
				++count;
			}
		}

		assembly ("memory-safe") {
			if xor(length, count) {
				mstore(addresses, count)
			}
		}
	}

	function loadCurrency(Config storage config, string memory key) internal view returns (Currency) {
		return Currency.wrap(loadAddress(config, key));
	}

	function loadCurrencyArray(
		Config storage config,
		string[] memory keys
	) internal view returns (Currency[] memory currencies) {
		address[] memory addresses = loadAddressArray(config, keys);

		assembly ("memory-safe") {
			currencies := addresses
		}
	}

	function loadWrappedNative(Config storage config) internal view returns (Currency) {
		return loadCurrency(config, config.json.readString(WRAPPED_NATIVE_PATH));
	}

	function loadAaveV3Config(Config storage config, string memory key) internal view returns (AaveV3Config memory) {
		return abi.decode(config.json.parseRaw(string.concat(AAVE_V3_PATH, ".", key)), (AaveV3Config));
	}

	function loadUniswapConfig(Config storage config) internal view returns (UniswapConfig memory) {
		return abi.decode(config.json.parseRaw(UNISWAP_PATH), (UniswapConfig));
	}
}
