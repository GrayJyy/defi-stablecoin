// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDecentralizedStableCoin {
    event CollateralDeposited(address indexed user, address tokenCollateralAddr, uint256 amountCollateral);
    event CollateralRedeemed(
        address indexed from, address indexed to, address tokenCollateralAddr, uint256 amountCollateral
    );

    function depositCollateralAndMintDsc(address acceptedToken, uint256 amountCollateral, uint256 expectedMint)
        external;

    /**
     *
     * @param tokenCollateralAddr The address of the collateral token to deposit
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddr, uint256 amountCollateral) external;
    function redeemCollateralForDsc(address expectedToken, uint256 expectedCollateralAmount, uint256 amountToBurn)
        external;
    function redeemCollateral(address expectedToken, uint256 expectedCollateralAmount) external;

    /**
     *
     * @param amountCollateral The amount of collateral to min't
     * @notice must have more collateral than the minimum collateral ratio
     */
    function mintDsc(uint256 amountCollateral) external;
    function burnDsc(uint256 amountToBurn) external;
    function liquidate(address collateral, address liquidatedUser, uint256 debtToCover) external;
    // function getHealthFactor() external view returns (uint256);
}
