// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "lib/forge-std/src/Vm.sol";
import {stdJson} from "lib/forge-std/src/StdJson.sol";
import {Currency} from "src/types/Currency.sol";
import {Config, AaveV3Config, UniswapConfig} from "./Config.sol";

abstract contract Configured {
	using stdJson for string;

	Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	uint256 internal constant ETHEREUM_CHAIN_ID = 1;
	uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

	uint256 internal constant OPTIMISM_CHAIN_ID = 10;
	uint256 internal constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

	uint256 internal constant POLYGON_CHAIN_ID = 137;

	uint256 internal constant ARBITRUM_CHAIN_ID = 42161;
	uint256 internal constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

	uint256 internal constant BASE_CHAIN_ID = 8453;
	uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

	Config internal config;
	string internal network;

	UniswapConfig internal uni;
	AaveV3Config internal aave;
	AaveV3Config internal lido;
	AaveV3Config internal etherfi;

	Currency[] internal allCurrencies;

	Currency internal constant NATIVE = Currency.wrap(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
	Currency internal WNATIVE;
	Currency internal WETH;
	Currency internal STETH;
	Currency internal WSTETH;
	Currency internal CBETH;
	Currency internal RETH;
	Currency internal WEETH;

	Currency internal DAI;
	Currency internal FRAX;
	Currency internal USDC;
	Currency internal USDCe;
	Currency internal USDT;

	Currency internal WBTC;
	Currency internal CBBTC;
	Currency internal AAVE;
	Currency internal COMP;
	Currency internal LINK;
	Currency internal UNI;

	function configure() internal virtual {
		if (block.chainid == 31337) vm.chainId(ETHEREUM_CHAIN_ID);

		uint256 chainId = block.chainid;
		require(chainId != 0, "chain id must be specified (`--chain <chainid>`)");

		if (chainId == ETHEREUM_CHAIN_ID) {
			network = "ethereum";
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			network = "optimism";
		} else if (chainId == POLYGON_CHAIN_ID) {
			network = "polygon";
		} else if (chainId == BASE_CHAIN_ID) {
			network = "base";
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			network = "arbitrum";
		} else {
			revert(string.concat("unsupported chain id: ", vm.toString(chainId)));
		}

		if (bytes(config.json).length == 0) {
			string memory root = vm.projectRoot();
			string memory path = string.concat(root, "/config/schema/", network, ".json");
			config.json = vm.readFile(path);
		}

		configureAssets();
		configureAaveV3(chainId);
		configureUniswap();
	}

	function configureAssets() internal virtual {
		WNATIVE = config.loadWrappedNative();

		Currency[17] memory currencies = [
			(WETH = config.loadCurrency("WETH")),
			(STETH = config.loadCurrency("stETH")),
			(WSTETH = config.loadCurrency("wstETH")),
			(CBETH = config.loadCurrency("cbETH")),
			(RETH = config.loadCurrency("rETH")),
			(WEETH = config.loadCurrency("weETH")),
			(DAI = config.loadCurrency("DAI")),
			(FRAX = config.loadCurrency("FRAX")),
			(USDC = config.loadCurrency("USDC")),
			(USDCe = config.loadCurrency("USDCe")),
			(USDT = config.loadCurrency("USDT")),
			(WBTC = config.loadCurrency("WBTC")),
			(CBBTC = config.loadCurrency("cbBTC")),
			(AAVE = config.loadCurrency("AAVE")),
			(COMP = config.loadCurrency("COMP")),
			(LINK = config.loadCurrency("LINK")),
			(UNI = config.loadCurrency("UNI"))
		];

		if (WNATIVE != WETH) allCurrencies.push(WNATIVE);

		for (uint256 i; i < currencies.length; ++i) {
			if (currencies[i].isZero()) continue;
			allCurrencies.push(currencies[i]);
		}
	}

	function configureAaveV3(uint256 chainId) internal virtual {
		aave = _configureAaveV3("aave");
		if (chainId == ETHEREUM_CHAIN_ID) {
			etherfi = _configureAaveV3("etherfi");
			lido = _configureAaveV3("lido");
		}
	}

	function _configureAaveV3(string memory key) internal virtual returns (AaveV3Config memory aaveV3) {
		aaveV3 = config.loadAaveV3Config(vm.toLowercase(key));
		label("PoolAddressesProvider", aaveV3.addressesProvider);
		label("Pool", aaveV3.pool);
		label("AaveOracle", aaveV3.oracle);
	}

	function configureUniswap() internal virtual {
		uni = config.loadUniswapConfig();
		label("UniversalRouter", uni.universalRouter);
		label("PoolManager", uni.poolManager);
		label("V2Factory", uni.v2Factory);
		label("V3Factory", uni.v3Factory);
		label("V3Quoter", uni.v3Quoter);
		label("V4Quoter", uni.v4Quoter);
		label("V4StateView", uni.v4StateView);
	}

	function label(string memory name, address target) internal virtual {
		if (target != address(0)) vm.label(target, name);
	}

	function getChainId() internal view virtual returns (uint256) {
		return config.json.readUint("$.chainId");
	}

	function getForkBlockNumber() internal view virtual returns (uint256) {
		return config.json.readUintOr("$.forkBlockNumber", 0);
	}

	function rpcAlias() internal view virtual returns (string memory) {
		return config.json.readString("$.rpcAlias");
	}
}
