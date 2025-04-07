// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Currency} from "src/types/Currency.sol";

/// @title WrappedNative

library WrappedNative {
	function get() internal view returns (Currency wn) {
		assembly ("memory-safe") {
			switch chainid()
			// Ethereum
			case 1 {
				wn := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
			}
			// Sepolia
			case 11155111 {
				wn := 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
			}
			// Optimism
			case 10 {
				wn := 0x4200000000000000000000000000000000000006
			}
			// Optimism Sepolia
			case 11155420 {
				wn := 0x4200000000000000000000000000000000000006
			}
			// BSC
			case 56 {
				wn := 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
			}
			// BSC Testnet
			case 97 {
				wn := 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd
			}
			// xDAI
			case 100 {
				wn := 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d
			}
			// Polygon
			case 137 {
				wn := 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
			}
			// Polygon Mumbai
			case 80001 {
				wn := 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
			}
			// Polygon Amoy
			case 80002 {
				wn := 0xA5733b3A8e62A8faF43b0376d5fAF46E89B3033E
			}
			// Fantom
			case 250 {
				wn := 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83
			}
			// Fantom Testnet
			case 4002 {
				wn := 0xf1277d1Ed8AD466beddF92ef448A132661956621
			}
			// Base
			case 8453 {
				wn := 0x4200000000000000000000000000000000000006
			}
			// Base Sepolia
			case 84532 {
				wn := 0x4200000000000000000000000000000000000006
			}
			// Arbitrum
			case 42161 {
				wn := 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
			}
			// Arbitrum Sepolia
			case 421614 {
				wn := 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73
			}
			// Avalanche
			case 43114 {
				wn := 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7
			}
			// Avalanche Fiji
			case 43113 {
				wn := 0xd00ae08403B9bbb9124bB305C09058E32C39A48c
			}
			default {
				mstore(0x00, 0xc3a55c98) // UnsupportedChain(uint256)
				mstore(0x20, chainid())
				revert(0x1c, 0x24)
			}
		}
	}
}
