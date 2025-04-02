// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMetaFactory} from "src/interfaces/factories/IMetaFactory.sol";
import {Execution} from "src/libraries/ExecutionLib.sol";
import {Currency} from "src/types/Currency.sol";
import {ModuleType} from "src/types/Types.sol";
import {ReentrancyGuard} from "src/modules/utils/ReentrancyGuard.sol";
import {ExecutorBase} from "src/modules/base/ExecutorBase.sol";

/// @title UniversalExecutor

contract UniversalExecutor is ExecutorBase, ReentrancyGuard {
	error UnsupportedProtocol(uint256 protocol);

	/// @dev keccak256("AccountRouterConfigured(address,address)")
	bytes32 private constant ACCOUNT_ROUTER_CONFIGURED_TOPIC =
		0xa8fd23d42b508ba2c717741779865ad45b6fc96f34a0124e880f44cad86076d4;

	/// @dev keccak256(abi.encode(uint256(keccak256("eip7579.executor.accountRouters")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 internal constant ACCOUNT_ROUTERS_STORAGE_SLOT =
		0x9c3dee6d7c92c0e43518da88f538f333487ac138b7cb037184debd2b16ed0d00;

	/// UniversalRouter Commands

	bytes1 internal constant V3_SWAP_EXACT_IN = 0x00;
	bytes1 internal constant V3_SWAP_EXACT_OUT = 0x01;
	bytes1 internal constant SWEEP = 0x04;
	bytes1 internal constant V2_SWAP_EXACT_IN = 0x08;
	bytes1 internal constant V2_SWAP_EXACT_OUT = 0x09;
	bytes1 internal constant PERMIT2_PERMIT = 0x0a;
	bytes1 internal constant WRAP_ETH = 0x0b;
	bytes1 internal constant UNWRAP_WETH = 0x0c;
	bytes1 internal constant V4_SWAP = 0x10;

	/// V4 Router Actions

	bytes1 internal constant V4_SWAP_EXACT_IN = 0x07;
	bytes1 internal constant V4_SWAP_EXACT_OUT = 0x09;
	bytes1 internal constant SETTLE_ALL = 0x0c;
	bytes1 internal constant TAKE_ALL = 0x0f;

	address internal constant MSG_SENDER = 0x0000000000000000000000000000000000000001;
	address internal constant ADDRESS_THIS = 0x0000000000000000000000000000000000000002;

	uint256 internal constant CONTRACT_BALANCE = 0x8000000000000000000000000000000000000000000000000000000000000000;

	uint256 internal constant SOURCE_ROUTER = 0x00;
	uint256 internal constant SOURCE_SENDER = 0x01;

	uint256 internal constant PROTOCOL_V4 = 0x04;
	uint256 internal constant PROTOCOL_V3 = 0x03;
	uint256 internal constant PROTOCOL_V2 = 0x02;

	Currency public immutable WRAPPED_NATIVE;

	constructor() {
		bytes memory context = IMetaFactory(msg.sender).parameters();
		Currency wrappedNative;

		assembly ("memory-safe") {
			if lt(mload(context), 0x20) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			wrappedNative := shr(0x60, shl(0x60, mload(add(context, 0x20))))
		}

		WRAPPED_NATIVE = wrappedNative;
	}

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		require(data.length == 20, InvalidDataLength());
		_setAccountRouter(_checkAccountRouter(address(bytes20(data))));
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

	function swapExactInput(bytes calldata params) external payable nonReentrant returns (bytes[] memory returnData) {
		(
			uint256 protocol,
			bytes calldata swapParams,
			bytes calldata permitParams,
			uint256 deadline
		) = _decodeSwapParams(params);

		if (protocol == PROTOCOL_V4) {
			return _v4SwapExactInput(swapParams, permitParams, deadline);
		} else if (protocol == PROTOCOL_V3) {
			return _v3SwapExactInput(swapParams, permitParams, deadline);
		} else if (protocol == PROTOCOL_V2) {
			return _v2SwapExactInput(swapParams, permitParams, deadline);
		} else {
			revert UnsupportedProtocol(protocol);
		}
	}

	function swapExactOutput(bytes calldata params) external payable nonReentrant returns (bytes[] memory returnData) {
		(
			uint256 protocol,
			bytes calldata swapParams,
			bytes calldata permitParams,
			uint256 deadline
		) = _decodeSwapParams(params);

		if (protocol == PROTOCOL_V4) {
			return _v4SwapExactOutput(swapParams, permitParams, deadline);
		} else if (protocol == PROTOCOL_V3) {
			return _v3SwapExactOutput(swapParams, permitParams, deadline);
		} else if (protocol == PROTOCOL_V2) {
			return _v2SwapExactOutput(swapParams, permitParams, deadline);
		} else {
			revert UnsupportedProtocol(protocol);
		}
	}

	function _v4SwapExactInput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency currencyIn;
		Currency currencyOut;

		uint128 amountIn;
		uint128 amountOutMin;

		assembly ("memory-safe") {
			if lt(swapParams.length, 0xa0) {
				mstore(0x00, 0x5037072d) // InvalidSwapParams()
				revert(0x1c, 0x04)
			}

			let ptr := add(add(swapParams.offset, 0x20), calldataload(add(swapParams.offset, 0x40)))
			let offset := add(ptr, 0x20)
			let length := shl(0x05, sub(calldataload(ptr), 0x01))

			currencyIn := calldataload(add(swapParams.offset, 0x20))
			currencyOut := calldataload(add(offset, calldataload(add(offset, length))))

			amountIn := calldataload(add(swapParams.offset, 0x60))
			amountOutMin := calldataload(add(swapParams.offset, 0x80))

			if iszero(amountIn) {
				mstore(0x00, 0xdf5b2ee6) // InsufficientAmountIn()
				revert(0x1c, 0x04)
			}

			if iszero(amountOutMin) {
				mstore(0x00, 0xebcb7f39) // InsufficientAmountOutMin()
				revert(0x1c, 0x04)
			}

			if and(iszero(currencyIn), lt(callvalue(), amountIn)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(iszero(currencyIn)), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory actions = abi.encodePacked(V4_SWAP_EXACT_IN, SETTLE_ALL, TAKE_ALL);

		bytes[] memory params = new bytes[](3);
		params[0] = swapParams;
		params[1] = abi.encode(currencyIn, amountIn);
		params[2] = abi.encode(currencyOut, amountOutMin);

		bytes memory commands;
		bytes[] memory inputs;

		if (currencyIn.isZero()) {
			commands = abi.encodePacked(V4_SWAP);

			inputs = new bytes[](1);
			inputs[0] = abi.encode(actions, params);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V4_SWAP);

			inputs = new bytes[](2);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(actions, params);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
	}

	function _v4SwapExactOutput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency currencyIn;
		Currency currencyOut;

		uint128 amountOut;
		uint128 amountInMax;

		assembly ("memory-safe") {
			if lt(swapParams.length, 0xa0) {
				mstore(0x00, 0x5037072d) // InvalidSwapParams()
				revert(0x1c, 0x04)
			}

			let offset := add(swapParams.offset, 0x40)
			let ptr := add(offset, calldataload(offset))

			currencyOut := calldataload(add(swapParams.offset, 0x20))
			currencyIn := calldataload(add(ptr, calldataload(ptr)))

			amountOut := calldataload(add(offset, 0x20))
			amountInMax := calldataload(add(offset, 0x40))

			if iszero(amountOut) {
				mstore(0x00, 0xe52970aa) // InsufficientAmountOut()
				revert(0x1c, 0x04)
			}

			if iszero(amountInMax) {
				mstore(0x00, 0x8d960379) // InsufficientAmountInMax()
				revert(0x1c, 0x04)
			}

			if and(iszero(currencyIn), lt(callvalue(), amountInMax)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(iszero(currencyIn)), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory actions = abi.encodePacked(V4_SWAP_EXACT_OUT, SETTLE_ALL, TAKE_ALL);

		bytes[] memory params = new bytes[](3);
		params[0] = swapParams;
		params[1] = abi.encode(currencyIn, amountInMax);
		params[2] = abi.encode(currencyOut, amountOut);

		bytes memory commands;
		bytes[] memory inputs = new bytes[](2);

		if (currencyIn.isZero()) {
			commands = abi.encodePacked(V4_SWAP, SWEEP);

			inputs[0] = abi.encode(actions, params);
			inputs[1] = abi.encode(currencyIn, MSG_SENDER, 0);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V4_SWAP);

			inputs[0] = permitParams;
			inputs[1] = abi.encode(actions, params);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
	}

	function _v3SwapExactInput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency wrappedNative = WRAPPED_NATIVE;
		bool useNative;

		bytes calldata path;
		Currency currencyIn;
		Currency currencyOut;

		uint128 amountIn;
		uint128 amountOutMin;

		assembly ("memory-safe") {
			path.offset := add(swapParams.offset, 0x04)
			path.length := shr(0xe0, calldataload(swapParams.offset))

			if or(lt(path.length, 0x2b), iszero(iszero(mod(sub(path.length, 0x14), 0x17)))) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyIn := shr(0x60, calldataload(path.offset))
			currencyOut := shr(0x60, calldataload(add(path.offset, sub(path.length, 0x14))))

			let amounts := calldataload(add(path.offset, path.length))
			amountIn := shr(0x80, amounts)
			amountOutMin := shr(0x80, shl(0x80, amounts))

			if iszero(amountIn) {
				mstore(0x00, 0xdf5b2ee6) // InsufficientAmountIn()
				revert(0x1c, 0x04)
			}

			if iszero(amountOutMin) {
				mstore(0x00, 0xebcb7f39) // InsufficientAmountOutMin()
				revert(0x1c, 0x04)
			}

			useNative := and(eq(currencyIn, wrappedNative), iszero(iszero(callvalue())))

			if and(useNative, lt(callvalue(), amountIn)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(useNative), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = abi.encodePacked(WRAP_ETH, V3_SWAP_EXACT_IN, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = abi.encode(ADDRESS_THIS, CONTRACT_BALANCE);
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, SOURCE_ROUTER);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = abi.encodePacked(PERMIT2_PERMIT, V3_SWAP_EXACT_IN, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(ADDRESS_THIS, amountIn, amountOutMin, path, SOURCE_SENDER);
			inputs[2] = abi.encode(MSG_SENDER, amountOutMin);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V3_SWAP_EXACT_IN);

			inputs = new bytes[](2);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, SOURCE_SENDER);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
	}

	function _v3SwapExactOutput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency wrappedNative = WRAPPED_NATIVE;
		bool useNative;

		bytes calldata path;
		Currency currencyIn;
		Currency currencyOut;

		uint128 amountOut;
		uint128 amountInMax;

		assembly ("memory-safe") {
			path.offset := add(swapParams.offset, 0x04)
			path.length := shr(0xe0, calldataload(swapParams.offset))

			if or(lt(path.length, 0x2b), iszero(iszero(mod(sub(path.length, 0x14), 0x17)))) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyOut := shr(0x60, calldataload(path.offset))
			currencyIn := shr(0x60, calldataload(add(path.offset, sub(path.length, 0x14))))

			let amounts := calldataload(add(path.offset, path.length))
			amountOut := shr(0x80, amounts)
			amountInMax := shr(0x80, shl(0x80, amounts))

			if iszero(amountOut) {
				mstore(0x00, 0xe52970aa) // InsufficientAmountOut()
				revert(0x1c, 0x04)
			}

			if iszero(amountInMax) {
				mstore(0x00, 0x8d960379) // InsufficientAmountInMax()
				revert(0x1c, 0x04)
			}

			useNative := and(eq(currencyIn, wrappedNative), iszero(iszero(callvalue())))

			if and(useNative, lt(callvalue(), amountInMax)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(useNative), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = abi.encodePacked(WRAP_ETH, V3_SWAP_EXACT_OUT, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = abi.encode(ADDRESS_THIS, CONTRACT_BALANCE);
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, SOURCE_ROUTER);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = abi.encodePacked(PERMIT2_PERMIT, V3_SWAP_EXACT_OUT, UNWRAP_WETH, SWEEP);

			inputs = new bytes[](4);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(ADDRESS_THIS, amountOut, amountInMax, path, SOURCE_SENDER);
			inputs[2] = abi.encode(MSG_SENDER, amountOut);
			inputs[3] = abi.encode(currencyIn, MSG_SENDER, 0);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V3_SWAP_EXACT_OUT, SWEEP);

			inputs = new bytes[](3);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, SOURCE_SENDER);
			inputs[2] = abi.encode(currencyIn, MSG_SENDER, 0);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
	}

	function _v2SwapExactInput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency wrappedNative = WRAPPED_NATIVE;
		bool useNative;

		Currency[] calldata path;
		Currency currencyIn;
		Currency currencyOut;

		uint128 amountIn;
		uint128 amountOutMin;

		assembly ("memory-safe") {
			let ptr := add(swapParams.offset, calldataload(swapParams.offset))
			path.offset := add(ptr, 0x20)
			path.length := calldataload(ptr)

			if lt(path.length, 0x02) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyIn := calldataload(path.offset)
			currencyOut := calldataload(add(path.offset, shl(0x05, sub(path.length, 0x01))))

			let amounts := calldataload(add(path.offset, shl(0x05, path.length)))
			amountIn := shr(0x80, amounts)
			amountOutMin := shr(0x80, shl(0x80, amounts))

			if iszero(amountIn) {
				mstore(0x00, 0xdf5b2ee6) // InsufficientAmountIn()
				revert(0x1c, 0x04)
			}

			if iszero(amountOutMin) {
				mstore(0x00, 0xebcb7f39) // InsufficientAmountOutMin()
				revert(0x1c, 0x04)
			}

			useNative := and(eq(currencyIn, wrappedNative), iszero(iszero(callvalue())))

			if and(useNative, lt(callvalue(), amountIn)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(useNative), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = abi.encodePacked(WRAP_ETH, V2_SWAP_EXACT_IN, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = abi.encode(ADDRESS_THIS, CONTRACT_BALANCE);
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, SOURCE_ROUTER);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = abi.encodePacked(PERMIT2_PERMIT, V2_SWAP_EXACT_IN, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(ADDRESS_THIS, amountIn, amountOutMin, path, SOURCE_SENDER);
			inputs[2] = abi.encode(MSG_SENDER, amountOutMin);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V2_SWAP_EXACT_IN);

			inputs = new bytes[](2);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(MSG_SENDER, amountIn, amountOutMin, path, SOURCE_SENDER);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
	}

	function _v2SwapExactOutput(
		bytes calldata swapParams,
		bytes calldata permitParams,
		uint256 deadline
	) internal virtual returns (bytes[] memory returnData) {
		address router = getAccountRouter(msg.sender);
		require(router != address(0), NotInitialized(msg.sender));

		Currency wrappedNative = WRAPPED_NATIVE;
		bool useNative;

		Currency[] calldata path;
		Currency currencyIn;
		Currency currencyOut;

		uint128 amountOut;
		uint128 amountInMax;

		assembly ("memory-safe") {
			let ptr := add(swapParams.offset, calldataload(swapParams.offset))
			path.offset := add(ptr, 0x20)
			path.length := calldataload(ptr)

			if lt(path.length, 0x02) {
				mstore(0x00, 0xcd608bfe) // InvalidPathLength()
				revert(0x1c, 0x04)
			}

			currencyIn := calldataload(path.offset)
			currencyOut := calldataload(add(path.offset, shl(0x05, sub(path.length, 0x01))))

			let amounts := calldataload(add(path.offset, shl(0x05, path.length)))
			amountOut := shr(0x80, amounts)
			amountInMax := shr(0x80, shl(0x80, amounts))

			if iszero(amountOut) {
				mstore(0x00, 0xe52970aa) // InsufficientAmountOut()
				revert(0x1c, 0x04)
			}

			if iszero(amountInMax) {
				mstore(0x00, 0x8d960379) // InsufficientAmountInMax()
				revert(0x1c, 0x04)
			}

			useNative := and(eq(currencyIn, wrappedNative), iszero(iszero(callvalue())))

			if and(useNative, lt(callvalue(), amountInMax)) {
				mstore(0x00, 0xbe8f8021) // InsufficientCallValue()
				revert(0x1c, 0x04)
			}

			if and(iszero(useNative), iszero(permitParams.length)) {
				mstore(0x00, 0xc6fc3b8a) // InvalidPermitParams()
				revert(0x1c, 0x04)
			}
		}

		bytes memory commands;
		bytes[] memory inputs;

		if (useNative) {
			commands = abi.encodePacked(WRAP_ETH, V2_SWAP_EXACT_OUT, UNWRAP_WETH);

			inputs = new bytes[](3);
			inputs[0] = abi.encode(ADDRESS_THIS, CONTRACT_BALANCE);
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, SOURCE_ROUTER);
			inputs[2] = abi.encode(MSG_SENDER, 0);
		} else if (currencyOut == WRAPPED_NATIVE) {
			commands = abi.encodePacked(PERMIT2_PERMIT, V2_SWAP_EXACT_OUT, UNWRAP_WETH, SWEEP);

			inputs = new bytes[](4);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(ADDRESS_THIS, amountOut, amountInMax, path, SOURCE_SENDER);
			inputs[2] = abi.encode(MSG_SENDER, amountOut);
			inputs[3] = abi.encode(currencyIn, MSG_SENDER, 0);
		} else {
			commands = abi.encodePacked(PERMIT2_PERMIT, V2_SWAP_EXACT_OUT, SWEEP);

			inputs = new bytes[](3);
			inputs[0] = permitParams;
			inputs[1] = abi.encode(MSG_SENDER, amountOut, amountInMax, path, SOURCE_SENDER);
			inputs[2] = abi.encode(currencyIn, MSG_SENDER, 0);
		}

		return _execute(router, msg.value, _encodeExecutionCommands(commands, inputs, deadline));
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

	function _encodeExecutionCommands(
		bytes memory commands,
		bytes[] memory inputs,
		uint256 deadline
	) internal pure virtual returns (bytes memory callData) {
		callData = deadline != 0
			? abi.encodeWithSelector(
				0x3593564c, // execute(bytes,bytes[],uint256)
				commands,
				inputs,
				deadline
			)
			: abi.encodeWithSelector(
				0x24856bc3, // execute(bytes,bytes[])
				commands,
				inputs
			);
	}

	function _decodeSwapParams(
		bytes calldata params
	)
		internal
		pure
		virtual
		returns (uint256 protocol, bytes calldata swapParams, bytes calldata permitParams, uint256 deadline)
	{
		assembly ("memory-safe") {
			let ptr := params.offset
			protocol := shr(0xf8, calldataload(ptr))

			ptr := add(ptr, 0x01)
			swapParams.length := shr(0xe0, calldataload(ptr))
			swapParams.offset := add(ptr, 0x04)

			ptr := add(swapParams.offset, swapParams.length)
			permitParams.length := shr(0xe0, calldataload(ptr))
			permitParams.offset := add(ptr, 0x04)

			ptr := add(permitParams.offset, permitParams.length)
			deadline := shr(0xd8, calldataload(ptr))
		}
	}
}
