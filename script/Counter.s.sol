// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ArbitrageHook} from "../src/ArbitrageHook.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        IPoolManager poolManager = IPoolManager(0xYourPoolManagerAddress); // Replace with your pool manager address
        ArbitrageHook arbitrageHook = new ArbitrageHook(poolManager);
        console.log("ArbitrageHook deployed at:", address(arbitrageHook));

        vm.stopBroadcast();
    }
}
