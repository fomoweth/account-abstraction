// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BytesLib} from "src/libraries/BytesLib.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {ReentrancyGuard} from "src/modules/utils/ReentrancyGuard.sol";
import {ExecutorBase} from "src/modules/base/ExecutorBase.sol";

/// @title UniversalExecutor

contract UniversalExecutor is ExecutorBase, ReentrancyGuard {
	using BytesLib for *;
	using CalldataDecoder for bytes;
	using SafeCast for uint256;

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

	/// @dev keccak256("AccountRouterConfigured(address,address)")
	bytes32 private constant ACCOUNT_ROUTER_CONFIGURED_TOPIC =
		0xa8fd23d42b508ba2c717741779865ad45b6fc96f34a0124e880f44cad86076d4;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.executor.accountRouters")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant ACCOUNT_ROUTERS_STORAGE_SLOT =
		0x9c3dee6d7c92c0e43518da88f538f333487ac138b7cb037184debd2b16ed0d00;

	bytes32 internal constant UNISWAP_V3_POOL_INIT_CODE_HASH =
		0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

	bytes32 internal constant UNISWAP_V2_PAIR_INIT_CODE_HASH =
		0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

	bytes4 internal constant APPROVE_SELECTOR = 0x095ea7b3;
	bytes4 internal constant EXECUTE_SELECTOR = 0x3593564c; // execute(bytes,bytes[],uint256)

	address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

	address internal constant ETH = 0x0000000000000000000000000000000000000000;
	address internal constant MSG_SENDER = 0x0000000000000000000000000000000000000001;
	address internal constant ADDRESS_THIS = 0x0000000000000000000000000000000000000002;

	// UniversalRouter Commands

	bytes1 internal constant V3_SWAP_EXACT_IN = 0x00;
	bytes1 internal constant V3_SWAP_EXACT_OUT = 0x01;
	bytes1 internal constant PERMIT2_TRANSFER_FROM = 0x02;
	bytes1 internal constant PERMIT2_PERMIT_BATCH = 0x03;
	bytes1 internal constant SWEEP = 0x04;
	bytes1 internal constant TRANSFER = 0x05;
	bytes1 internal constant PAY_PORTION = 0x06;

	bytes1 internal constant V2_SWAP_EXACT_IN = 0x08;
	bytes1 internal constant V2_SWAP_EXACT_OUT = 0x09;
	bytes1 internal constant PERMIT2_PERMIT = 0x0a;
	bytes1 internal constant WRAP_ETH = 0x0b;
	bytes1 internal constant UNWRAP_WETH = 0x0c;
	bytes1 internal constant PERMIT2_TRANSFER_FROM_BATCH = 0x0d;
	bytes1 internal constant BALANCE_CHECK_ERC20 = 0x0e;

	bytes1 internal constant V4_SWAP = 0x10;
	bytes1 internal constant V3_POSITION_MANAGER_PERMIT = 0x11;
	bytes1 internal constant V3_POSITION_MANAGER_CALL = 0x12;
	bytes1 internal constant V4_INITIALIZE_POOL = 0x13;
	bytes1 internal constant V4_POSITION_MANAGER_CALL = 0x14;

	uint256 internal constant MAX_UINT256 = (1 << 256) - 1;
	uint48 internal constant MAX_UINT48 = (1 << 48) - 1;

	address public immutable UNISWAP_V4_POOL_MANAGER;
	address public immutable UNISWAP_V3_FACTORY;
	address public immutable UNISWAP_V2_FACTORY;
	Currency public immutable WRAPPED_NATIVE;

	constructor(address poolManager, address uniswapV3Factory, address uniswapV2Factory, Currency wrappedNative) {
		UNISWAP_V4_POOL_MANAGER = poolManager;
		UNISWAP_V3_FACTORY = uniswapV3Factory;
		UNISWAP_V2_FACTORY = uniswapV2Factory;
		WRAPPED_NATIVE = wrappedNative;
	}

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(data.length == 20, InvalidDataLength());
		_setAccountRouter(_checkAccountRouter(data.toAddress()));
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountRouter(address(0));
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function setAccountRouter(address router) external {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_setAccountRouter(_checkAccountRouter(router));
	}

	function getAccountRouter(address account) public view virtual returns (address router) {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, account)))
			mstore(0x20, ACCOUNT_ROUTERS_STORAGE_SLOT)
			router := sload(keccak256(0x00, 0x40))
		}
	}

	function v3SwapExactInput(
		address account,
		bytes calldata path,
		uint256 amountIn,
		uint256 amountOutMin,
		bytes calldata permit // abi.encode(((address,uint160,uint48,uint48),address,uint256),bytes)
	) external payable nonReentrant returns (bytes[] memory returnData) {
		return _v3Swap(account, path, amountIn, amountOutMin, true, permit);
	}

	function v3SwapExactOutput(
		address account,
		bytes calldata path,
		uint256 amountOut,
		uint256 amountInMax,
		bytes calldata permit // abi.encode(((address,uint160,uint48,uint48),address,uint256),bytes)
	) external payable nonReentrant returns (bytes[] memory returnData) {
		return _v3Swap(account, path, amountOut, amountInMax, false, permit);
	}

	function v2SwapExactInput(
		address account,
		Currency[] calldata path,
		uint256 amountIn,
		uint256 amountOutMin,
		bytes calldata permit // abi.encode(((address,uint160,uint48,uint48),address,uint256),bytes)
	) external payable nonReentrant returns (bytes[] memory returnData) {
		return _v2Swap(account, path, amountIn, amountOutMin, true, permit);
	}

	function v2SwapExactOutput(
		address account,
		Currency[] calldata path,
		uint256 amountOut,
		uint256 amountInMax,
		bytes calldata permit // abi.encode(((address,uint160,uint48,uint48),address,uint256),bytes)
	) external payable nonReentrant returns (bytes[] memory returnData) {
		return _v2Swap(account, path, amountOut, amountInMax, false, permit);
	}

	function computePool(Currency currency0, Currency currency1, uint24 fee) external view returns (address pool) {
		return _computePool(UNISWAP_V3_FACTORY, currency0, currency1, fee);
	}

	function computePair(Currency currency0, Currency currency1) external view returns (address pair) {
		return _computePair(UNISWAP_V2_FACTORY, currency0, currency1);
	}

	function name() external pure returns (string memory) {
		return "UniversalExecutor";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) external pure returns (bool) {
		return moduleTypeId == TYPE_EXECUTOR;
	}

	function _isInitialized(address account) internal view virtual returns (bool result) {
		return getAccountRouter(account) != address(0);
	}

	function _setAccountRouter(address router) internal virtual {
		assembly ("memory-safe") {
			mstore(0x00, shr(0x60, shl(0x60, caller())))
			mstore(0x20, ACCOUNT_ROUTERS_STORAGE_SLOT)
			sstore(keccak256(0x00, 0x40), router)
			log3(0x00, 0x00, ACCOUNT_ROUTER_CONFIGURED_TOPIC, caller(), router)
		}
	}

	function _checkAccountRouter(address router) internal view virtual returns (address) {
		assembly ("memory-safe") {
			router := shr(0x60, shl(0x60, router))
			if iszero(extcodesize(router)) {
				mstore(0x00, 0x3194ca7b) // InvalidAccountRouter()
				revert(0x1c, 0x04)
			}
		}

		return router;
	}

	function _v3Swap(
		address account,
		bytes calldata path,
		uint256 amount, // amountIn || amountOut
		uint256 limit, // amountOutMin || amountInMax
		bool isExactIn,
		bytes calldata permit
	) internal virtual returns (bytes[] memory returnData) {
		Execution[] memory executions = new Execution[](2);
		uint256 count;

		unchecked {
			if (permit.length != 0) {
				Currency currencyIn = path[isExactIn ? 0 : path.length - 20:].toCurrency();

				if (currencyIn.allowance(account, PERMIT2) != MAX_UINT256) {
					executions[count] = Execution({
						target: currencyIn.toAddress(),
						value: 0,
						callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
					});
					++count;
				}
			}

			executions[count] = isExactIn
				? _encodeV3ExactInput(account, path, amount, limit, permit)
				: _encodeV3ExactOutput(account, path, amount, limit, permit);
			++count;

			assembly ("memory-safe") {
				if xor(mload(executions), count) {
					mstore(executions, count)
				}
			}
		}

		return _execute(account, executions);
	}

	function _v2Swap(
		address account,
		Currency[] calldata path,
		uint256 amount, // amountIn || amountOut
		uint256 limit, // amountOutMin || amountInMax
		bool isExactIn,
		bytes calldata permit
	) internal virtual returns (bytes[] memory returnData) {
		Execution[] memory executions = new Execution[](2);
		uint256 count;

		unchecked {
			if (permit.length != 0) {
				Currency currencyIn = path[isExactIn ? 0 : path.length - 1];

				if (currencyIn.allowance(account, PERMIT2) != MAX_UINT256) {
					executions[count] = Execution({
						target: currencyIn.toAddress(),
						value: 0,
						callData: abi.encodeWithSelector(APPROVE_SELECTOR, PERMIT2, MAX_UINT256)
					});
					++count;
				}
			}

			executions[count] = isExactIn
				? _encodeV2ExactInput(account, path, amount, limit, permit)
				: _encodeV2ExactOutput(account, path, amount, limit, permit);
			++count;
		}

		return _execute(account, executions);
	}

	function _encodeV3ExactInput(
		address account,
		bytes calldata path,
		uint256 amountIn,
		uint256 amountOutMin,
		bytes calldata permit
	) internal view virtual returns (Execution memory execution) {
		(Currency currencyIn, Currency currencyOut) = _validateV3Path(path);
		bool useNative = currencyIn == WRAPPED_NATIVE && permit.length == 0;

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = new bytes(2);
			commands[0] = WRAP_ETH;
			commands[1] = V3_SWAP_EXACT_IN;

			inputs = new bytes[](2);
			inputs[0] = abi.encode(ADDRESS_THIS, amountIn);
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, false);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = new bytes(3);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V3_SWAP_EXACT_IN;
			commands[2] = UNWRAP_WETH;

			inputs = new bytes[](3);
			inputs[0] = permit;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, true);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else {
			commands = new bytes(2);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V3_SWAP_EXACT_IN;

			inputs = new bytes[](2);
			inputs[0] = permit;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, true);
		}

		execution = Execution({
			target: getAccountRouter(account),
			value: useNative ? amountIn : 0,
			callData: abi.encodeWithSelector(
				EXECUTE_SELECTOR,
				commands,
				inputs,
				permit.toUint256(5) // sigDeadline
			)
		});
	}

	function _encodeV3ExactOutput(
		address account,
		bytes calldata path,
		uint256 amountOut,
		uint256 amountInMax,
		bytes calldata permit
	) internal view returns (Execution memory execution) {
		(Currency currencyOut, Currency currencyIn) = _validateV3Path(path);
		bool useNative = currencyIn == WRAPPED_NATIVE && permit.length == 0;

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = new bytes(3);
			commands[0] = WRAP_ETH;
			commands[1] = V3_SWAP_EXACT_OUT;
			commands[2] = UNWRAP_WETH;

			inputs = new bytes[](3);
			inputs[0] = abi.encode(ADDRESS_THIS, amountInMax);
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, false);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = new bytes(4);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V3_SWAP_EXACT_OUT;
			commands[2] = UNWRAP_WETH;
			commands[3] = SWEEP;

			inputs = new bytes[](4);
			inputs[0] = permit;
			inputs[1] = abi.encode(ADDRESS_THIS, amountOut, amountInMax, path, true);
			inputs[2] = abi.encode(MSG_SENDER, amountOut);
			inputs[3] = abi.encode(currencyIn, MSG_SENDER, 0);
		} else {
			commands = new bytes(3);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V3_SWAP_EXACT_OUT;
			commands[2] = SWEEP;

			inputs = new bytes[](3);
			inputs[0] = permit;
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, true);
			inputs[2] = abi.encode(currencyIn, MSG_SENDER, 0);
		}

		execution = Execution({
			target: getAccountRouter(account),
			value: useNative ? amountInMax : 0,
			callData: abi.encodeWithSelector(
				EXECUTE_SELECTOR,
				commands,
				inputs,
				permit.toUint256(5) // sigDeadline
			)
		});
	}

	function _encodeV2ExactInput(
		address account,
		Currency[] calldata path,
		uint256 amountIn,
		uint256 amountOutMin,
		bytes calldata permit
	) internal view virtual returns (Execution memory execution) {
		(Currency currencyIn, Currency currencyOut) = _validateV2Path(path);
		bool useNative = currencyIn == WRAPPED_NATIVE && permit.length == 0;

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = new bytes(2);
			commands[0] = WRAP_ETH;
			commands[1] = V2_SWAP_EXACT_IN;

			inputs = new bytes[](2);
			inputs[0] = abi.encode(_computePair(UNISWAP_V2_FACTORY, path[0], path[1]), amountIn);
			inputs[1] = abi.encode(MSG_SENDER, 0, amountOutMin, path, false);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = new bytes(3);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V2_SWAP_EXACT_IN;
			commands[2] = UNWRAP_WETH;

			inputs = new bytes[](3);
			inputs[0] = permit;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, true);
			inputs[2] = abi.encode(MSG_SENDER, amountOutMin);
		} else {
			commands = new bytes(2);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V2_SWAP_EXACT_IN;

			inputs = new bytes[](2);
			inputs[0] = permit;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, true);
		}

		execution = Execution({
			target: getAccountRouter(account),
			value: useNative ? amountIn : 0,
			callData: abi.encodeWithSelector(
				EXECUTE_SELECTOR,
				commands,
				inputs,
				permit.toUint256(5) // sigDeadline
			)
		});
	}

	function _encodeV2ExactOutput(
		address account,
		Currency[] calldata path,
		uint256 amountOut,
		uint256 amountInMax,
		bytes calldata permit
	) internal view virtual returns (Execution memory execution) {
		(Currency currencyIn, Currency currencyOut) = _validateV2Path(path);
		bool useNative = currencyIn == WRAPPED_NATIVE && permit.length == 0;

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = new bytes(3);
			commands[0] = WRAP_ETH;
			commands[1] = V2_SWAP_EXACT_OUT;
			commands[2] = UNWRAP_WETH;

			inputs = new bytes[](3);
			inputs[0] = abi.encode(_computePair(UNISWAP_V2_FACTORY, path[0], path[1]), amountInMax);
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, false);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = new bytes(4);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V2_SWAP_EXACT_OUT;
			commands[2] = UNWRAP_WETH;
			commands[3] = SWEEP;

			inputs = new bytes[](4);
			inputs[0] = permit;
			inputs[1] = abi.encode(ADDRESS_THIS, amountOut, amountInMax, path, true);
			inputs[2] = abi.encode(MSG_SENDER, amountOut);
			inputs[3] = abi.encode(currencyIn, MSG_SENDER, 0);
		} else {
			commands = new bytes(3);
			commands[0] = PERMIT2_PERMIT;
			commands[1] = V2_SWAP_EXACT_OUT;
			commands[2] = SWEEP;

			inputs = new bytes[](3);
			inputs[0] = permit;
			inputs[1] = abi.encode(ADDRESS_THIS, amountOut, amountInMax, path, true);
			inputs[2] = abi.encode(currencyIn, MSG_SENDER, 0);
		}

		execution = Execution({
			target: getAccountRouter(account),
			value: useNative ? amountInMax : 0,
			callData: abi.encodeWithSelector(
				EXECUTE_SELECTOR,
				commands,
				inputs,
				permit.toUint256(5) // sigDeadline
			)
		});
	}

	function _computePool(
		address factory,
		Currency currency0,
		Currency currency1,
		uint24 fee
	) internal view virtual returns (address pool) {
		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(ptr, add(hex"ff", shl(0x58, factory)))
			mstore(add(ptr, 0x15), shr(0x60, shl(0x60, currency0)))
			mstore(add(ptr, 0x35), shr(0x60, shl(0x60, currency1)))
			mstore(add(ptr, 0x55), and(fee, 0xffffff))
			mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
			mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)

			pool := shr(0x60, shl(0x60, keccak256(ptr, 0x55)))

			if iszero(extcodesize(pool)) {
				mstore(0x00, 0x0ba98f1c) // PoolNotExists()
				revert(0x1c, 0x04)
			}
		}
	}

	function _computePair(
		address factory,
		Currency currency0,
		Currency currency1
	) internal view virtual returns (address pair) {
		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(ptr, add(hex"ff", shl(0x58, factory)))
			mstore(add(ptr, 0x15), shl(0x60, currency0))
			mstore(add(ptr, 0x29), shl(0x60, currency1))
			mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x28))
			mstore(add(ptr, 0x35), UNISWAP_V2_PAIR_INIT_CODE_HASH)

			pair := shr(0x60, shl(0x60, keccak256(ptr, 0x55)))

			if iszero(extcodesize(pair)) {
				mstore(0x00, 0x0022d46a) // PairNotExists()
				revert(0x1c, 0x04)
			}
		}
	}

	function _validateV3Path(
		bytes calldata path
	) internal pure virtual returns (Currency currencyIn, Currency currencyOut) {
		assembly ("memory-safe") {
			if or(lt(path.length, 43), iszero(iszero(mod(sub(path.length, 20), 23)))) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyIn := shr(0x60, calldataload(path.offset))
			currencyOut := shr(0x60, calldataload(add(path.offset, sub(path.length, 0x14))))

			if eq(currencyIn, currencyOut) {
				mstore(0x00, 0xd07bec9c) // IdenticalCurrencies()
				revert(0x1c, 0x04)
			}
		}
	}

	function _validateV2Path(
		Currency[] calldata path
	) internal pure virtual returns (Currency currencyIn, Currency currencyOut) {
		assembly ("memory-safe") {
			if lt(path.length, 0x02) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyIn := shr(0x60, shl(0x60, calldataload(path.offset)))
			currencyOut := shr(0x60, shl(0x60, calldataload(add(path.offset, shl(0x05, sub(path.length, 0x01))))))

			if eq(currencyIn, currencyOut) {
				mstore(0x00, 0xd07bec9c) // IdenticalCurrencies()
				revert(0x1c, 0x04)
			}
		}
	}
}
