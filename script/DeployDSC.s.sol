// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    constructor() {}

    function run() external returns (DecentralizedStableCoin dsc, DSCEngine dscEngine, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        console.log("wethUsdPriceFeed: %s", wethUsdPriceFeed);
        console.log("wbtcUsdPriceFeed: %s", wbtcUsdPriceFeed);
        console.log("weth: %s", weth);
        console.log("wbtc: %s", wbtc);
        console.log("deployerKey: %s", deployerKey);
        vm.startBroadcast(deployerKey);
        dsc = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
        dsc.transferOwnership(address(dscEngine)); // cuz the dsc is Ownable, so we need to transfer the ownership to the dscEngine
        vm.stopBroadcast();
        console.log("dsc: %s", address(dsc));
        console.log("dscEngine: %s", address(dscEngine));
    }
}
