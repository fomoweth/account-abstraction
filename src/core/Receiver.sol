// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Receiver
/// @notice This contract receives safe-transferred ERC721 and ERC1155 tokens

abstract contract Receiver {
	modifier receiverFallback() virtual {
		assembly ("memory-safe") {
			let selector := shr(0xe0, calldataload(0x00))
			// 0x150b7a02: onERC721Received(address,address,uint256,bytes)
			// 0xf23a6e61: onERC1155Received(address,address,uint256,uint256,bytes)
			// 0xbc197c81: onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
			if or(eq(selector, 0x150b7a02), or(eq(selector, 0xf23a6e61), eq(selector, 0xbc197c81))) {
				mstore(0x20, selector)
				return(0x3c, 0x20)
			}
		}
		_;
	}
}
