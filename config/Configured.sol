// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "lib/forge-std/src/Vm.sol";
import {Currency} from "src/types/Currency.sol";
import {Config, UniswapConfig} from "./Config.sol";

contract Configured {
	Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	uint256 internal constant ETHEREUM_CHAIN_ID = 1;
	uint256 internal constant OPTIMISM_CHAIN_ID = 10;
	uint256 internal constant POLYGON_CHAIN_ID = 137;
	uint256 internal constant ARBITRUM_CHAIN_ID = 42161;

	string internal constant ETHEREUM_NETWORK = "ethereum";
	string internal constant OPTIMISM_NETWORK = "optimism";
	string internal constant POLYGON_NETWORK = "polygon";
	string internal constant ARBITRUM_NETWORK = "arbitrum";

	Config internal config;

	string internal network;

	UniswapConfig internal uniswap;

	Currency[] internal allCurrencies;
	Currency[] internal lsdNatives;
	Currency[] internal stablecoins;

	Currency internal WNATIVE;
	Currency internal WETH;
	Currency internal STETH;
	Currency internal WSTETH;
	Currency internal FRXETH;
	Currency internal SFRXETH;
	Currency internal CBETH;
	Currency internal RETH;
	Currency internal WEETH;

	Currency internal DAI;
	Currency internal FRAX;
	Currency internal USDC;
	Currency internal USDCe;
	Currency internal USDT;

	Currency internal WBTC;
	Currency internal AAVE;
	Currency internal COMP;
	Currency internal LINK;
	Currency internal UNI;

	function configure() internal virtual {
		if (block.chainid == 31337) vm.chainId(ETHEREUM_CHAIN_ID);
		uint256 chainId = block.chainid;

		if (chainId == 0) {
			revert("chain id must be specified (`--chain <chainid>`)");
		} else if (chainId == ETHEREUM_CHAIN_ID) {
			network = ETHEREUM_NETWORK;
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			network = OPTIMISM_NETWORK;
		} else if (chainId == POLYGON_CHAIN_ID) {
			network = POLYGON_NETWORK;
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			network = ARBITRUM_NETWORK;
		} else {
			revert(string.concat("Unsupported chain: ", vm.toString(chainId)));
		}

		if (bytes(config.json).length == 0) {
			string memory root = vm.projectRoot();
			string memory path = string.concat(root, "/config/schema/", network, ".json");

			config.json = vm.readFile(path);
		}

		configureAssets();
		configureUniswap();
	}

	function configureAssets() internal virtual {
		WETH = config.getCurrency("WETH");
		STETH = config.getCurrency("stETH");
		WSTETH = config.getCurrency("wstETH");
		FRXETH = config.getCurrency("frxETH");
		SFRXETH = config.getCurrency("sfrxETH");
		CBETH = config.getCurrency("cbETH");
		RETH = config.getCurrency("rETH");
		WEETH = config.getCurrency("weETH");

		DAI = config.getCurrency("DAI");
		FRAX = config.getCurrency("FRAX");
		USDC = config.getCurrency("USDC");
		USDCe = config.getCurrency("USDCe");
		USDT = config.getCurrency("USDT");

		WBTC = config.getCurrency("WBTC");
		AAVE = config.getCurrency("AAVE");
		COMP = config.getCurrency("COMP");
		LINK = config.getCurrency("LINK");
		UNI = config.getCurrency("UNI");

		Currency[18] memory currencies = [
			WETH,
			STETH,
			WSTETH,
			FRXETH,
			SFRXETH,
			CBETH,
			RETH,
			WEETH,
			DAI,
			FRAX,
			USDC,
			USDCe,
			USDT,
			WBTC,
			AAVE,
			COMP,
			LINK,
			UNI
		];

		if (WNATIVE != WETH) allCurrencies.push(WNATIVE);

		for (uint256 i; i < currencies.length; ++i) {
			if (currencies[i].isZero()) continue;
			allCurrencies.push(currencies[i]);
		}

		lsdNatives = config.getLsdNatives();
		stablecoins = config.getStablecoins();
	}

	function configureUniswap() internal virtual {
		uniswap = config.getUniswapConfig();
	}

	function getChainId() internal view virtual returns (uint256) {
		return config.getChainId();
	}

	function getForkBlockNumber() internal view virtual returns (uint256) {
		return config.getForkBlockNumber();
	}

	function rpcAlias() internal view virtual returns (string memory) {
		return config.getRpcAlias();
	}
}
