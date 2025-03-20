// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";

struct AaveV3Config {
	address addressesProvider;
	address oracle;
	address pool;
}

struct UniswapConfig {
	address poolManager;
	address universalRouter;
	address v2Factory;
	address v3Factory;
	address v3Quoter;
	address v4Quoter;
	address v4StateView;
}

struct Permit {
	address owner;
	address spender;
	uint256 value;
	uint256 nonce;
	uint256 deadline;
}

struct PermitDetails {
	Currency currency;
	uint160 amount;
	uint48 expiration;
	uint48 nonce;
}

struct PermitSingle {
	PermitDetails details;
	address spender;
	uint256 sigDeadline;
}

struct PermitBatch {
	PermitDetails[] details;
	address spender;
	uint256 sigDeadline;
}

struct PackedUserOperation {
	address sender;
	uint256 nonce;
	bytes initCode;
	bytes callData;
	bytes32 accountGasLimits;
	uint256 preVerificationGas;
	bytes32 gasFees;
	bytes paymasterAndData;
	bytes signature;
}
