// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    constructor() {}

    function run() external returns (DecentralizedStableCoin dsc, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        console.log("wethUsdPriceFeed: %s", wethUsdPriceFeed);
        console.log("wbtcUsdPriceFeed: %s", wbtcUsdPriceFeed);
        console.log("weth: %s", weth);
        console.log("wbtc: %s", wbtc);
        console.log("deployerKey: %s", deployerKey);
        vm.startBroadcast(deployerKey);
        dsc = new DecentralizedStableCoin();
        vm.stopBroadcast();
        console.log("dsc: %s", address(dsc));
    }
}
