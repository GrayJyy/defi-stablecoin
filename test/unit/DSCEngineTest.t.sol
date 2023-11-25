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
    address public user = makeAddr("user");
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    constructor() {}

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey,) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_BALANCE); // prank and give user some money
        }
        ERC20Mock(weth).mint(user, STARTING_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_BALANCE);
    }

    function testGetUsdValue_ShouldCalculatesCorrectly_WhenParamsAreRight() public {
        uint256 amount = 1e18;
        uint256 expectedValue = 1e18 * 2000e8 * 1e10 / 1e18;
        uint256 actualValue = dscEngine.getUsdValue(weth, amount);
        assertEq(actualValue, expectedValue);
    }

    function testDepositCollateral_ShouldReverts_WhenAmountLessThanZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
