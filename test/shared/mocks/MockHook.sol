// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ModuleType} from "src/types/Types.sol";
import {HookBase} from "src/modules/base/HookBase.sol";

contract MockHook is HookBase {
	event LogPreCheck(address account, bytes accountData, address msgSender, uint256 msgValue, bytes msgData);
	event LogPostCheck(address account, bytes context);

	error InvalidAccount();
	error InvalidAccountData();
	error InvalidMsgSender();
	error InvalidMsgValue();
	error InvalidMsgData();

	mapping(address account => bool isInstalled) internal _isInstalled;
	mapping(address account => bytes data) internal _accountData;

	/// @dev bytes32(uint256(keccak256("account")) - 1)
	bytes32 public constant ACCOUNT_SLOT = 0xd844bb55167ab332117049e2ccd3d8863d241bcc80f46302310a6d942a90e850;

	/// @dev bytes32(uint256(keccak256("accountData")) - 1)
	bytes32 public constant ACCOUNT_DATA_SLOT = 0xd99c780451d9589cdd83ff1d8ed0684df210618b9ee75f785e13dd0b0f50a0bc;

	/// @dev bytes32(uint256(keccak256("msgSender")) - 1)
	bytes32 public constant MSG_SENDER_SLOT = 0x92d1ab7c2e926a8b0c0c873d3b809f7236b38c75135b8c33df2a722097f5486c;

	/// @dev bytes32(uint256(keccak256("msgValue")) - 1)
	bytes32 public constant MSG_VALUE_SLOT = 0x22b631f9536ce10e1c528e6fbfa1a31b8b90f6d7b15c83120655a1274d1c4141;

	/// @dev bytes32(uint256(keccak256("msgData")) - 1)
	bytes32 public constant MSG_DATA_SLOT = 0xa82b740e76fc933fae1c74ee6ccc29bd2a816a3d4e55e2545c942ed2447cac7e;

	function onInstall(bytes calldata data) external payable {
		require(!_isInitialized(msg.sender), AlreadyInitialized(msg.sender));
		_isInstalled[msg.sender] = true;
		_accountData[msg.sender] = data;
	}

	function onUninstall(bytes calldata) external payable {
		require(_isInitialized(msg.sender), NotInitialized(msg.sender));
		_isInstalled[msg.sender] = false;
		delete _accountData[msg.sender];
	}

	function isInitialized(address account) external view returns (bool) {
		return _isInitialized(account);
	}

	function setAccountData(address account, bytes calldata data) external {
		_accountData[account] = data;
	}

	function getAccountData(address account) external view returns (bytes memory data) {
		return _accountData[account];
	}

	function _preCheck(
		address account,
		address msgSender,
		uint256 msgValue,
		bytes calldata msgData
	) internal virtual override returns (bytes memory context) {
		bytes memory accountData = _accountData[account];

		_cache(ACCOUNT_DATA_SLOT, accountData);
		_cache(MSG_DATA_SLOT, msgData);

		assembly ("memory-safe") {
			tstore(ACCOUNT_SLOT, shr(0x60, shl(0x60, account)))
			tstore(MSG_SENDER_SLOT, shr(0x60, shl(0x60, msgSender)))
			tstore(MSG_VALUE_SLOT, msgValue)
		}

		context = abi.encode(accountData, abi.encodePacked(msgSender, msgValue, msgData));

		emit LogPreCheck(account, accountData, msgSender, msgValue, msgData);
	}

	function _postCheck(address account, bytes calldata context) internal virtual override {
		bytes calldata accountData;
		bytes calldata msgData;
		address msgSender;
		uint256 msgValue;

		assembly ("memory-safe") {
			let ptr := add(context.offset, calldataload(context.offset))
			accountData.length := calldataload(ptr)
			accountData.offset := add(ptr, 0x20)

			ptr := add(context.offset, calldataload(add(context.offset, 0x20)))
			context.length := calldataload(ptr)
			context.offset := add(ptr, 0x20)

			if iszero(gt(context.length, 0x33)) {
				mstore(0x00, 0x3b99b53d) // SliceOutOfBounds()
				revert(0x1c, 0x04)
			}

			msgSender := shr(0x60, calldataload(context.offset))
			msgValue := calldataload(add(context.offset, 0x14))
			msgData.offset := add(context.offset, 0x34)
			msgData.length := sub(context.length, 0x34)
		}

		bytes memory accountDataCached = _load(ACCOUNT_DATA_SLOT);
		bytes memory msgDataCached = _load(MSG_DATA_SLOT);
		address accountCached;
		address msgSenderCached;
		uint256 msgValueCached;

		assembly ("memory-safe") {
			accountCached := tload(ACCOUNT_SLOT)
			msgSenderCached := tload(MSG_SENDER_SLOT)
			msgValueCached := tload(MSG_VALUE_SLOT)

			tstore(ACCOUNT_SLOT, 0x00)
			tstore(ACCOUNT_DATA_SLOT, 0x00)
			tstore(MSG_SENDER_SLOT, 0x00)
			tstore(MSG_VALUE_SLOT, 0x00)
			tstore(MSG_DATA_SLOT, 0x00)
		}

		require(account == accountCached, InvalidAccount());
		require(keccak256(accountData) == keccak256(accountDataCached), InvalidAccountData());
		require(msgSender == msgSenderCached, InvalidMsgSender());
		require(msgValue == msgValueCached, InvalidMsgValue());
		require(keccak256(msgData) == keccak256(msgDataCached), InvalidMsgData());

		emit LogPostCheck(account, context);
	}

	function name() external pure returns (string memory) {
		return "MockHook";
	}

	function version() external pure returns (string memory) {
		return "1.0.0";
	}

	function isModuleType(ModuleType moduleTypeId) public pure virtual returns (bool) {
		return moduleTypeId == TYPE_HOOK;
	}

	function _isInitialized(address account) internal view returns (bool) {
		return _isInstalled[account];
	}

	function _cache(bytes32 slot, bytes memory data) internal virtual {
		assembly ("memory-safe") {
			let length := mload(data)
			let offset := add(data, 0x20)
			tstore(slot, mload(sub(offset, 0x04)))

			if gt(length, sub(0x20, 0x04)) {
				mstore(0x00, slot)
				let derivedSlot := keccak256(0x00, 0x20)
				let ptr := add(offset, sub(0x20, 0x04))
				let guard := sub(add(offset, length), 0x01)

				// prettier-ignore
				for { } 0x01 { } {
					tstore(derivedSlot, mload(ptr))
					ptr := add(ptr, 0x20)
					if gt(ptr, guard) { break }
					derivedSlot := add(derivedSlot, 0x01)
				}
			}
		}
	}

	function _load(bytes32 slot) internal view virtual returns (bytes memory returndata) {
		assembly ("memory-safe") {
			returndata := mload(0x40)
			mstore(returndata, 0x00)
			mstore(add(returndata, sub(0x20, 0x04)), tload(slot))

			let length := mload(returndata)
			let offset := add(returndata, 0x20)
			mstore(0x40, add(offset, length))

			if gt(length, sub(0x20, 0x04)) {
				mstore(0x00, slot)
				let derivedSlot := keccak256(0x00, 0x20)
				let ptr := add(offset, sub(0x20, 0x04))
				let guard := add(offset, length)

				// prettier-ignore
				for { } 0x01 { } {
					mstore(ptr, tload(derivedSlot))
					ptr := add(ptr, 0x20)
					if gt(ptr, guard) { break }
					derivedSlot := add(derivedSlot, 0x01)
				}

				mstore(guard, 0x00)
			}
		}
	}
}
