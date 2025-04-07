// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {stdJson} from "lib/forge-std/src/StdJson.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {MetadataLib} from "src/libraries/MetadataLib.sol";
import {Currency} from "src/types/Currency.sol";
import {AaveV3Config, UniswapConfig} from "test/shared/structs/Protocols.sol";

struct Config {
	uint256 chainId;
	string network;
	uint256 blockNumber;
	string json;
}

abstract contract Configured {
	using stdJson for string;
	using MetadataLib for Currency;

	mapping(string => address) internal addresses;

	Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

	uint256 internal constant ETHEREUM_CHAIN_ID = 1;
	uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

	uint256 internal constant OPTIMISM_CHAIN_ID = 10;
	uint256 internal constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

	uint256 internal constant POLYGON_CHAIN_ID = 137;
	uint256 internal constant POLYGON_AMOY_CHAIN_ID = 80002;

	uint256 internal constant BASE_CHAIN_ID = 8453;
	uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

	uint256 internal constant ARBITRUM_CHAIN_ID = 42161;
	uint256 internal constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

	string internal constant CHAIN_ID_PATH = "$.chainId";
	string internal constant FORK_BLOCK_NUMBER_PATH = "$.forkBlockNumber";
	string internal constant RPC_ALIAS_PATH = "$.rpcAlias";

	string internal constant AAVE_V3_PATH = "$.AAVE_V3";
	string internal constant UNISWAP_PATH = "$.UNISWAP";

	Config internal config;

	uint256 internal forkId = configure();

	Currency internal constant NATIVE = Currency.wrap(address(0));
	Currency internal immutable WNATIVE = getCurrency("WNATIVE");

	Currency internal immutable WETH = getCurrency("WETH");
	Currency internal immutable STETH = getCurrency("STETH");
	Currency internal immutable WSTETH = getCurrency("WSTETH");
	Currency internal immutable FRXETH = getCurrency("FRXETH");
	Currency internal immutable SFRXETH = getCurrency("SFRXETH");
	Currency internal immutable CBETH = getCurrency("CBETH");
	Currency internal immutable RETH = getCurrency("RETH");
	Currency internal immutable WEETH = getCurrency("WEETH");

	Currency internal immutable DAI = getCurrency("DAI");
	Currency internal immutable USDC = getCurrency("USDC");
	Currency internal immutable USDCe = getCurrency("USDCe");
	Currency internal immutable USDT = getCurrency("USDT");

	Currency internal immutable WBTC = getCurrency("WBTC");
	Currency internal immutable CBBTC = getCurrency("CBBTC");

	modifier onlyEthereum() {
		vm.skip(!isEthereum());
		_;
	}

	modifier onlyOptimism() {
		vm.skip(!isOptimism());
		_;
	}

	modifier onlyPolygon() {
		vm.skip(!isPolygon());
		_;
	}

	modifier onlyBase() {
		vm.skip(!isBase());
		_;
	}

	modifier onlyArbitrum() {
		vm.skip(!isArbitrum());
		_;
	}

	function isEthereum() internal view virtual returns (bool) {
		return block.chainid == ETHEREUM_CHAIN_ID;
	}

	function isOptimism() internal view virtual returns (bool) {
		return block.chainid == OPTIMISM_CHAIN_ID;
	}

	function isPolygon() internal view virtual returns (bool) {
		return block.chainid == POLYGON_CHAIN_ID;
	}

	function isBase() internal view virtual returns (bool) {
		return block.chainid == BASE_CHAIN_ID;
	}

	function isArbitrum() internal view virtual returns (bool) {
		return block.chainid == ARBITRUM_CHAIN_ID;
	}

	function configure() internal virtual returns (uint256) {
		if (bytes(config.json).length != 0) return forkId;
		if (block.chainid == 31337) vm.chainId(ETHEREUM_CHAIN_ID);

		config.chainId = block.chainid;
		require(config.chainId != 0, "chain id must be specified (`--chain <chainid>`)");

		if (config.chainId == ETHEREUM_CHAIN_ID) {
			config.network = "ethereum";
		} else if (config.chainId == OPTIMISM_CHAIN_ID) {
			config.network = "optimism";
		} else if (config.chainId == POLYGON_CHAIN_ID) {
			config.network = "polygon";
		} else if (config.chainId == BASE_CHAIN_ID) {
			config.network = "base";
		} else if (config.chainId == ARBITRUM_CHAIN_ID) {
			config.network = "arbitrum";
		} else {
			revert(string.concat("unsupported chain id: ", vm.toString(config.chainId)));
		}

		config.json = vm.readFile(string.concat("config/schema/", config.network, ".json"));

		configureAaveV3();
		configureUniswap();

		if ((config.blockNumber = config.json.readUintOr(FORK_BLOCK_NUMBER_PATH, 0)) != 0) {
			return vm.createSelectFork(vm.rpcUrl(config.network), config.blockNumber);
		} else {
			return vm.createSelectFork(vm.rpcUrl(config.network));
		}
	}

	function setAddress(address target, string memory name) internal virtual {
		if (target != address(0)) vm.label((addresses[name] = target), name);
	}

	function setAddress(string memory key, string memory name) internal virtual {
		setAddress(readAddress(key), name);
	}

	function getAddress(string memory name) internal view virtual returns (address) {
		return addresses[name];
	}

	function readAddress(string memory key) internal view virtual returns (address) {
		return config.json.readAddressOr(string.concat("$.", key), address(0));
	}

	function getCurrency(string memory key) internal virtual returns (Currency currency) {
		return Currency.wrap(readAddress(key));
	}

	function configureAaveV3() internal virtual {
		configureAaveV3("Aave");

		if (block.chainid == ETHEREUM_CHAIN_ID) {
			configureAaveV3("EtherFi");
			configureAaveV3("Lido");
		}
	}

	function configureAaveV3(string memory protocol) internal virtual {
		string memory key = string.concat(AAVE_V3_PATH, ".", vm.toLowercase(protocol));
		AaveV3Config memory aaveV3 = abi.decode(config.json.parseRaw(key), (AaveV3Config));

		setAddress(aaveV3.addressesProvider, string.concat(protocol, "PoolAddressesProvider"));
		setAddress(aaveV3.pool, string.concat(protocol, "Pool"));
		setAddress(aaveV3.oracle, string.concat(protocol, "Oracle"));
	}

	function configureUniswap() internal virtual {
		UniswapConfig memory uniswap = abi.decode(config.json.parseRaw(UNISWAP_PATH), (UniswapConfig));

		setAddress(uniswap.universalRouter, "UniversalRouter");
		setAddress(uniswap.poolManager, "PoolManager");
		setAddress(uniswap.v4StateView, "StateView");
		setAddress(uniswap.v4Quoter, "V4Quoter");
		setAddress(uniswap.v3Quoter, "V3Quoter");
		setAddress(uniswap.v3Factory, "V3Factory");
		setAddress(uniswap.v2Factory, "V2Factory");
	}

	function labelCurrencies() internal virtual {
		if (WNATIVE != WETH) labelCurrency(WNATIVE);

		Currency[14] memory currencies = [
			WETH,
			STETH,
			WSTETH,
			FRXETH,
			SFRXETH,
			CBETH,
			RETH,
			WEETH,
			DAI,
			USDC,
			USDCe,
			USDT,
			WBTC,
			CBBTC
		];

		for (uint256 i; i < currencies.length; ++i) {
			labelCurrency(currencies[i]);
		}
	}

	function labelCurrency(Currency currency) internal virtual {
		label(currency.toAddress(), currency.readSymbol());
	}

	function label(address target, string memory name) internal virtual returns (address) {
		if (target != address(0)) vm.label(target, name);
		return target;
	}

	function getChainId() internal view virtual returns (uint256) {
		return config.json.readUint(CHAIN_ID_PATH);
	}

	function getForkBlockNumber() internal view virtual returns (uint256) {
		return config.json.readUintOr(FORK_BLOCK_NUMBER_PATH, 0);
	}

	function rpcAlias() internal view virtual returns (string memory) {
		return config.json.readString(RPC_ALIAS_PATH);
	}
}
