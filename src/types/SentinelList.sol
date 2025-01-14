// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CustomRevert} from "src/libraries/CustomRevert.sol";

using SentinelListLibrary for SentinelList global;

struct SentinelList {
	mapping(address prev => address entry) entries;
}

/// @title SentinelListLibrary
/// @dev Implementation from https://github.com/rhinestonewtf/sentinellist/blob/main/src/SentinelList.sol

library SentinelListLibrary {
	using CustomRevert for bytes4;

	error EntryExistsAlready(address entry);
	error InitializedAlready();
	error InvalidEntry(address entry);
	error InvalidPage();

	address internal constant SENTINEL = 0x0000000000000000000000000000000000000001;
	address internal constant ZERO = 0x0000000000000000000000000000000000000000;

	function initialize(SentinelList storage self) internal {
		if (isInitialized(self)) InitializedAlready.selector.revertWith();
		self.entries[SENTINEL] = SENTINEL;
	}

	function push(SentinelList storage self, address newEntry) internal {
		if (!_isValidEntry(newEntry)) InvalidEntry.selector.revertWith(newEntry);
		if (self.entries[newEntry] != ZERO) EntryExistsAlready.selector.revertWith(newEntry);

		self.entries[newEntry] = self.entries[SENTINEL];
		self.entries[SENTINEL] = newEntry;
	}

	function safePush(SentinelList storage self, address newEntry) internal {
		if (!self.isInitialized()) self.initialize();
		self.push(newEntry);
	}

	function pop(SentinelList storage self, address prevEntry, address popEntry) internal {
		if (!_isValidEntry(popEntry)) InvalidEntry.selector.revertWith(prevEntry);
		if (popEntry != self.entries[prevEntry]) InvalidEntry.selector.revertWith(popEntry);

		self.entries[prevEntry] = self.entries[popEntry];
		self.entries[popEntry] = ZERO;
	}

	function popAll(SentinelList storage self) internal {
		address next = self.entries[SENTINEL];
		while (next != ZERO) {
			address current = next;
			next = self.entries[next];
			self.entries[current] = ZERO;
		}
	}

	function isInitialized(SentinelList storage self) internal view returns (bool) {
		return self.entries[SENTINEL] != ZERO;
	}

	function isEmpty(SentinelList storage self) internal view returns (bool) {
		return !_isValidEntry(self.entries[SENTINEL]);
	}

	function contains(SentinelList storage self, address entry) internal view returns (bool) {
		return entry != SENTINEL && self.entries[entry] != ZERO;
	}

	function getNext(SentinelList storage self, address entry) internal view returns (address) {
		if (entry == ZERO) InvalidEntry.selector.revertWith(entry);
		return self.entries[entry];
	}

	function paginate(
		SentinelList storage self,
		address cursor,
		uint256 pageSize
	) internal view returns (address[] memory array, address nextCursor) {
		if (cursor != SENTINEL && !self.contains(cursor)) InvalidEntry.selector.revertWith(cursor);
		if (pageSize == 0) InvalidPage.selector.revertWith();

		array = new address[](pageSize);

		uint256 entryCount;
		nextCursor = self.entries[cursor];

		unchecked {
			while (_isValidEntry(nextCursor) && entryCount < pageSize) {
				array[entryCount] = nextCursor;
				nextCursor = self.entries[nextCursor];
				++entryCount;
			}

			if (nextCursor != SENTINEL && entryCount != 0) {
				nextCursor = array[entryCount - 1];
			}
		}

		assembly ("memory-safe") {
			mstore(array, entryCount)
		}
	}

	function _isValidEntry(address entry) private pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := iszero(or(eq(entry, SENTINEL), iszero(entry)))
		}
	}
}
