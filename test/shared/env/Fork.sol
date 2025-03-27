// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {MetadataLib} from "src/libraries/MetadataLib.sol";
import {Currency} from "src/types/Currency.sol";

import {Configured} from "config/Configured.sol";
import {Constants} from "./Constants.sol";

abstract contract Fork is Test, Configured, Constants {
	using MetadataLib for Currency;

	uint256 internal forkId;

	modifier onlyEthereum() {
		vm.skip(block.chainid != ETHEREUM_CHAIN_ID);
		_;
	}

	modifier onlyOptimism() {
		vm.skip(block.chainid != OPTIMISM_CHAIN_ID);
		_;
	}

	modifier onlyPolygon() {
		vm.skip(block.chainid != POLYGON_CHAIN_ID);
		_;
	}

	modifier onlyBase() {
		vm.skip(block.chainid != BASE_CHAIN_ID);
		_;
	}

	modifier onlyArbitrum() {
		vm.skip(block.chainid != ARBITRUM_CHAIN_ID);
		_;
	}

	function configure() internal virtual override {
		super.configure();

		fork(rpcAlias(), getForkBlockNumber());
		label("EntryPoint", address(ENTRYPOINT));
		label("Registry", address(REGISTRY));
		label("SmartSession", address(SMART_SESSION));
		label("Permit2", address(PERMIT2));
		labelCurrencies();
	}

	function fork(string memory rpcAlias, uint256 blockNumber) internal virtual {
		if (blockNumber != 0) {
			forkId = vm.createSelectFork(vm.rpcUrl(rpcAlias), blockNumber);
		} else {
			forkId = vm.createSelectFork(vm.rpcUrl(rpcAlias));
		}
	}

	function deal(Currency currency, address account, uint256 value, bool adjust) internal virtual {
		if (currency.isNative() || currency.isZero()) {
			deal(account, value);
		} else if (currency == STETH) {
			(, bytes memory returndata) = currency.toAddress().staticcall(abi.encodeWithSelector(0xf5eb42dc, account));
			uint256 balancePrior = abi.decode(returndata, (uint256));
			bytes32 balanceSlot = keccak256(abi.encode(account, uint256(0)));
			vm.store(currency.toAddress(), balanceSlot, bytes32(value));

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				vm.store(currency.toAddress(), STETH_TOTAL_SHARES_SLOT, bytes32(totalSupply));
			}
		} else if (currency == AAVE) {
			vm.assume(value < MAX_UINT104);

			uint256 balancePrior = currency.balanceOf(account);
			bytes32 balanceSlot = keccak256(abi.encode(account, uint256(0)));
			vm.store(currency.toAddress(), balanceSlot, bytes32(value));

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				vm.store(currency.toAddress(), bytes32(uint256(2)), bytes32(totalSupply));
			}
		} else {
			deal(currency.toAddress(), account, value, adjust);
		}
	}

	function deal(Currency currency, address account, uint256 value) internal virtual {
		deal(currency, account, value, false);
	}

	function labelCurrencies() internal virtual {
		for (uint256 i; i < allCurrencies.length; ++i) {
			labelCurrency(allCurrencies[i]);
		}
	}

	function labelCurrency(Currency currency) internal virtual {
		label(currency.readSymbol(), currency.toAddress());
	}
}
