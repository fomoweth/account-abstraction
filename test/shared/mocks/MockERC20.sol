// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
	constructor(string memory name, string memory symbol) ERC20(name, symbol) {
		_mint(msg.sender, 10_000_000 * 10 ** decimals());
	}

	function mint(address sender, uint256 amount) external {
		_mint(sender, amount);
	}

	function burn(address sender, uint256 amount) external {
		_burn(sender, amount);
	}
}
