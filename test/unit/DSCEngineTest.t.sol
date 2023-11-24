// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCEngineTest is Test {
    HelperConfig public helperConfig;
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;
    address public initOwner;
    address public user = makeAddr("user");
    uint256 public constant STARTING_BALANCE = 100 ether;

    constructor() {}

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey, initOwner) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_BALANCE);
        }
        ERC20Mock(weth).mint(user, STARTING_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_BALANCE);
    }

    // function testConstructor_ShouldReverts_WhenLengthNotEquall() public {
    //     address[] memory tokenAddresses = new address[](1);
    //     address[] memory priceFeedAddresses = new address[](2);
    //     vm.expectRevert(DSCEngine.DSCEngine__TheAddressListLengthNotMatch.selector);
    // }
}
