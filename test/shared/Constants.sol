// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ExecutionMode, CallType, ExecType} from "src/types/ExecutionMode.sol";

abstract contract Constants {
	IEntryPoint internal constant ENTRYPOINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

	bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	bytes32 internal constant STETH_TOTAL_SHARES_SLOT =
		0xe3b4b636e601189b5f4c6742edf2538ac12bb61ed03e6da26949d69838fa447e;

	bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
	bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

	bytes4 internal constant SUPPORTS_ERC7739 = 0x77390000;
	bytes4 internal constant SUPPORTS_ERC7739_V1 = 0x77390001;

	bytes1 internal constant CALLTYPE_SINGLE = 0x00;
	bytes1 internal constant CALLTYPE_BATCH = 0x01;
	bytes1 internal constant CALLTYPE_STATIC = 0xFE;
	bytes1 internal constant CALLTYPE_DELEGATE = 0xFF;

	bytes1 internal constant EXECTYPE_DEFAULT = 0x00;
	bytes1 internal constant EXECTYPE_TRY = 0x01;

	bytes1 internal constant MODE_VALIDATION = 0x00;
	bytes1 internal constant MODE_MODULE_ENABLE = 0x01;

	bytes3 internal constant BATCH_ID_DEFAULT = 0x000000;

	uint256 internal constant MODULE_TYPE_MULTI = 0;
	uint256 internal constant MODULE_TYPE_VALIDATOR = 1;
	uint256 internal constant MODULE_TYPE_EXECUTOR = 2;
	uint256 internal constant MODULE_TYPE_FALLBACK = 3;
	uint256 internal constant MODULE_TYPE_HOOK = 4;

	uint256 internal constant VALIDATION_SUCCESS = 0;
	uint256 internal constant VALIDATION_FAILED = 1;

	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;
	uint160 internal constant MAX_UINT160 = (1 << 160) - 1;
	uint104 internal constant MAX_UINT104 = (1 << 104) - 1;
}
