// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Math} from "src/libraries/Math.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {ExecutionModeLib as ModeLib, ExecutionMode, CallType} from "src/types/ExecutionMode.sol";
import {ModuleTypeLib, ModuleType, PackedModuleTypes} from "src/types/ModuleType.sol";
import {BaseTest} from "test/shared/env/BaseTest.sol";
import {Vortex} from "src/Vortex.sol";

abstract contract FactoryTest is BaseTest {
	using SafeCast for *;

	function validateDeployment(Vortex account) internal virtual {
		assertContract(address(account));

		assertEq(
			bytes32ToAddress(vm.load(address(account), ERC1967_IMPLEMENTATION_SLOT)),
			address(ACCOUNT_IMPLEMENTATION)
		);

		assertEq(account.accountId(), "fomoweth.vortex.1.0.0");
		assertEq(account.registry(), address(REGISTRY));
		assertEq(account.rootValidator(), address(K1_VALIDATOR));
		assertEq(K1_VALIDATOR.getAccountOwner(address(account)), ALICE_ADDRESS);
		assertEq(K1_VALIDATOR.getSafeSenders(address(account)), SENDER_ADDRESSES);

		assertTrue(
			account.supportsModule(TYPE_VALIDATOR) &&
				account.supportsModule(TYPE_EXECUTOR) &&
				account.supportsModule(TYPE_FALLBACK) &&
				account.supportsModule(TYPE_HOOK) &&
				account.supportsModule(TYPE_STATELESS_VALIDATOR)
		);

		assertTrue(
			account.supportsExecutionMode(ModeLib.encodeSingle()) &&
				account.supportsExecutionMode(ModeLib.encodeTrySingle())
		);

		assertTrue(
			account.supportsExecutionMode(ModeLib.encodeBatch()) &&
				account.supportsExecutionMode(ModeLib.encodeTryBatch())
		);

		assertTrue(
			account.supportsExecutionMode(ModeLib.encodeDelegate()) &&
				account.supportsExecutionMode(ModeLib.encodeTryDelegate())
		);

		if (initializerFlag == INITIALIZER_DEFAULT) {
			assertTrue(account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));
			assertTrue(account.isModuleInstalled(TYPE_VALIDATOR, address(MOCK_VALIDATOR), ""));
			assertTrue(account.isModuleInstalled(TYPE_EXECUTOR, address(MOCK_EXECUTOR), ""));

			(bytes4[] memory selectors, CallType[] memory callTypes) = MOCK_FALLBACK.getSupportedCalls();

			for (uint256 i; i < selectors.length; ++i) {
				bytes memory context = abi.encodePacked(selectors[i], callTypes[i]);
				assertTrue(account.isModuleInstalled(TYPE_FALLBACK, address(MOCK_FALLBACK), context));
			}
		} else if (initializerFlag == INITIALIZER_SCOPED) {
			assertTrue(account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));
		} else {
			assertFalse(account.isModuleInstalled(TYPE_HOOK, address(MOCK_HOOK), ""));
			assertEq(account.hook(), SENTINEL);
		}
	}

	function setInitializer(uint8 index) internal {
		setInitializerFlag(toFlag(index));
	}

	function toFlag(uint8 index) internal pure returns (bytes1) {
		return bytes1(Math.isEven(index).toUint().toUint8());
	}
}
