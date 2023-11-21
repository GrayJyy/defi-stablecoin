// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDecentralizedStableCoin {
    event CollateralDeposited(address indexed user, address tokenCollateralAddr, uint256 amountCollateral);

    function depositCollateralAndMintDsc() external;

    /**
     *
     * @param tokenCollateralAddr The address of the collateral token to deposit
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddr, uint256 amountCollateral) external;
    function redeemCollaternalForDsc() external;
    function redeemCollaternal() external;
    function burnDsc() external;
    function liquidate() external;
}
