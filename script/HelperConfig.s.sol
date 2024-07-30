// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported();

    struct NetworkConfig {
        address ethUsdPriceFeed;
        address btcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
        address initOwner;
    }

    address public user = makeAddr("user");
    uint8 public constant DECIMALS_8 = 8;
    int256 public constant ETH_USD_PRICE_2000e8 = 2000e8;
    int256 public constant BTC_USD_PRICE_1000e8 = 1000e8;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            revert HelperConfig__ChainIdNotSupported();
        }
    }

    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory _anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.ethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS_8,
            ETH_USD_PRICE_2000e8
        );
        ERC20Mock wethMock = new ERC20Mock();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS_8,
            BTC_USD_PRICE_1000e8
        );
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();
        (address anvilAddr, uint256 anvilKey) = makeAddrAndKey("local");
        _anvilNetworkConfig = NetworkConfig({
            ethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
            weth: address(wethMock),
            btcUsdPriceFeed: address(btcUsdPriceFeed),
            wbtc: address(wbtcMock),
            deployerKey: anvilKey,
            initOwner: anvilAddr
        });
    }

    function getSepoliaNetworkConfig() internal view returns (NetworkConfig memory _sepoliaNotworkConfig) {
        _sepoliaNotworkConfig = NetworkConfig({
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            btcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            initOwner: 0xF42f4b5cb102b3f5A180E08E6BA726c0179D172E
        });
    }
}
