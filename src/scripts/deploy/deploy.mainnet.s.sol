// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@forge-std/src/Script.sol";
import "@contracts/sweep/TroveSmolSweeper.sol";

contract MyScript is Script {
    TroveSmolSweeper smolsweeper;

    function run() external {
        vm.startBroadcast();

        smolsweeper = new TroveSmolSweeper(
            0x68D25992B1b04bE8A70104dE8Cb598170aB9aAD5,
            0xB0c7a3Ba49C7a6EaBa6cD4a96C55a1391070Ac9A,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );

        vm.stopBroadcast();
    }
}
