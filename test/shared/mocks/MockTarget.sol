// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockTarget {
	event MockEvent(address indexed sender, address indexed self);
	event Log(address indexed sender, bool indexed isDelegate);
	event Incremented(address indexed sender, uint256 indexed counter, bool indexed isDelegate);
	event Decremented(address indexed sender, uint256 indexed counter, bool indexed isDelegate);

	address public immutable self = address(this);

	uint256 private counter;

	function sendValue(address target, uint256 value) public payable {
		assembly ("memory-safe") {
			if iszero(call(gas(), target, value, codesize(), 0x00, codesize(), 0x00)) {
				revert(codesize(), 0x00)
			}
		}
	}

	function increment() public {
		emit Incremented(msg.sender, ++counter, address(this) != self);
	}

	function decrement() public {
		emit Decremented(msg.sender, --counter, address(this) != self);
	}

	function setCounter(uint256 value) public {
		counter = value;
		emit Log(msg.sender, address(this) != self);
	}

	function getCounter() public view returns (uint256) {
		return counter;
	}

	function emitEvent(bool shouldRevert) public payable {
		if (shouldRevert) revert("MockTarget: Revert operation");
		emit Log(msg.sender, address(this) != self);
	}

	receive() external payable {}
}
