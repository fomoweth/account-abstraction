// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "lib/forge-std/src/StdJson.sol";
import {Currency} from "src/types/Currency.sol";

using ConfigLibrary for Config global;

struct Config {
	string json;
}

struct UniswapConfig {
	address positionManager;
	address quoter;
	address router;
	address staker;
	address universalRouter;
	address v2Factory;
	address v3Factory;
}

library ConfigLibrary {
	using stdJson for string;

	/// https://crates.io/crates/jsonpath-rust

	string internal constant CHAIN_ID_PATH = "$.chainId";
	string internal constant RPC_ALIAS_PATH = "$.rpcAlias";
	string internal constant FORK_BLOCK_NUMBER_PATH = "$.forkBlockNumber";

	string internal constant WRAPPED_NATIVE_PATH = "$.wrappedNative";
	string internal constant LSD_NATIVES_PATH = "$.lsdNatives";
	string internal constant STABLECOINS_PATH = "$.stablecoins";

	string internal constant UNISWAP_PATH = "$.uniswap";

	function getAddress(Config storage config, string memory key) internal view returns (address) {
		return config.json.readAddressOr(string.concat("$.", key), address(0));
	}

	function getAddressArray(Config storage config, string memory key) internal view returns (address[] memory) {
		return config.json.readAddressArrayOr(string.concat("$.", key), new address[](0));
	}

	function getAddressArray(
		Config storage config,
		string[] memory keys
	) internal view returns (address[] memory addresses) {
		uint256 length = keys.length;
		uint256 count;

		addresses = new address[](length);

		for (uint256 i; i < length; ++i) {
			address target = getAddress(config, keys[i]);

			if (target != address(0)) {
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

	function getCurrency(Config storage config, string memory key) internal view returns (Currency) {
		return Currency.wrap(getAddress(config, key));
	}

	function getCurrencyArray(
		Config storage config,
		string[] memory keys
	) internal view returns (Currency[] memory currencies) {
		address[] memory addresses = getAddressArray(config, keys);

		assembly ("memory-safe") {
			currencies := addresses
		}
	}

	function getChainId(Config storage config) internal view returns (uint256) {
		return config.json.readUint(CHAIN_ID_PATH);
	}

	function getRpcAlias(Config storage config) internal view returns (string memory) {
		return config.json.readString(RPC_ALIAS_PATH);
	}

	function getForkBlockNumber(Config storage config) internal view returns (uint256) {
		return config.json.readUintOr(FORK_BLOCK_NUMBER_PATH, 0);
	}

	function getWrappedNative(Config storage config) internal view returns (Currency) {
		return getCurrency(config, config.json.readString(WRAPPED_NATIVE_PATH));
	}

	function getLsdNatives(Config storage config) internal view returns (Currency[] memory) {
		return getCurrencyArray(config, config.json.readStringArrayOr(LSD_NATIVES_PATH, new string[](0)));
	}

	function getStablecoins(Config storage config) internal view returns (Currency[] memory) {
		return getCurrencyArray(config, config.json.readStringArrayOr(STABLECOINS_PATH, new string[](0)));
	}

	function getUniswapConfig(Config storage config) internal view returns (UniswapConfig memory) {
		return abi.decode(config.json.parseRaw(UNISWAP_PATH), (UniswapConfig));
	}
}
