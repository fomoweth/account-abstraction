// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

import {MetadataLib} from "src/libraries/MetadataLib.sol";
import {Currency} from "src/types/Currency.sol";

import {Deployers} from "./Deployers.sol";
import {EventsAndErrors} from "./EventsAndErrors.sol";

abstract contract BaseTest is Test, Deployers, EventsAndErrors {
	using MetadataLib for Currency;
	using stdStorage for StdStorage;

	uint256 internal forkId;

	uint256 internal snapshotId = MAX_UINT256;

	modifier asEntryPoint() {
		vm.startPrank(address(ENTRYPOINT));
		_;
		vm.stopPrank();
	}

	function configure() internal virtual override {
		super.configure();
		fork();
		label(address(ENTRYPOINT), "EntryPoint");
		label(address(REGISTRY), "Registry");
		label(address(DEFAULT_RESOLVER), "DefaultResolver");
		label(address(DEFAULT_SCHEMA), "DefaultSchema");
		labelCurrencies();
	}

	function setUp() public virtual {
		configure();
		setUpUsers();
		setUpContracts();
	}

	function fork() internal virtual {
		uint256 forkBlockNumber = getForkBlockNumber();
		if (forkBlockNumber != 0) {
			forkId = vm.createSelectFork(vm.rpcUrl(rpcAlias()), forkBlockNumber);
		} else {
			forkId = vm.createSelectFork(vm.rpcUrl(rpcAlias()));
		}
	}

	function revertToState() internal virtual {
		if (snapshotId != MAX_UINT256) vm.revertToState(snapshotId);
		snapshotId = vm.snapshotState();
	}

	function deal(Currency currency, address account, uint256 value, bool adjust) internal virtual {
		if (currency.isZero() || value == 0) return;

		if (currency.isNative()) {
			vm.deal(account, value);
		} else if (currency == STETH) {
			address token = currency.toAddress();
			(, bytes memory returndata) = token.staticcall(abi.encodeWithSelector(0xf5eb42dc, account));

			uint256 balancePrior = abi.decode(returndata, (uint256));
			bytes32 balanceSlot = keccak256(abi.encode(account, uint256(0)));

			vm.store(token, balanceSlot, bytes32(value));

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				vm.store(token, STETH_TOTAL_SHARES_SLOT, bytes32(totalSupply));
			}
		} else if (currency == AAVE) {
			vm.assume(value < MAX_UINT104);

			address token = currency.toAddress();

			uint256 balancePrior = currency.balanceOf(account);
			bytes32 balanceSlot = keccak256(abi.encode(account, uint256(0)));

			vm.store(token, balanceSlot, bytes32(value));

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				vm.store(token, bytes32(uint256(2)), bytes32(totalSupply));
			}
		} else {
			address token = currency.toAddress();
			uint256 balancePrior = currency.balanceOf(account);

			stdstore.target(token).sig(0x70a08231).with_key(account).checked_write(value);

			if (adjust) {
				uint256 totalSupply = currency.totalSupply();

				if (value < balancePrior) {
					totalSupply -= (balancePrior - value);
				} else {
					totalSupply += (value - balancePrior);
				}

				stdstore.target(token).sig(0x18160ddd).checked_write(totalSupply);
			}
		}
	}

	function deal(Currency currency, address account, uint256 amount) internal virtual {
		deal(currency, account, amount, false);
	}

	function labelCurrencies() internal virtual {
		for (uint256 i; i < allCurrencies.length; ++i) {
			labelCurrency(allCurrencies[i]);
		}
	}

	function labelCurrency(Currency currency) internal virtual {
		label(currency.toAddress(), currency.readSymbol());
	}
}
