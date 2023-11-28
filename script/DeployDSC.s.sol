// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address public constant INITIAL_OWNER = 0xF42f4b5cb102b3f5A180E08E6BA726c0179D172E;

    constructor() {}

    function run() external returns (DecentralizedStableCoin dsc, DSCEngine dscEngine, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (
            address ethUsdPriceFeed,
            address btcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey,
            address initOwner
        ) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [ethUsdPriceFeed, btcUsdPriceFeed];
        console.log("ethUsdPriceFeed: %s", ethUsdPriceFeed);
        console.log("btcUsdPriceFeed: %s", btcUsdPriceFeed);
        console.log("weth: %s", weth);
        console.log("wbtc: %s", wbtc);
        vm.startBroadcast(deployerKey);
        dsc = new DecentralizedStableCoin(initOwner);
        dscEngine = new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
        dsc.transferOwnership(address(dscEngine)); // cuz the dsc is Ownable, so we need to transfer the ownership to the dscEngine
        vm.stopBroadcast();
        console.log("dsc: %s", address(dsc));
        console.log("dscEngine: %s", address(dscEngine));
    }
}
