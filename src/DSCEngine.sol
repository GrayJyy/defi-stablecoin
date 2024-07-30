// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IDecentralizedStableCoin} from "./interface/IDecentralizedStableCoin.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author GrayJiang
 * @notice The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is IDecentralizedStableCoin, ReentrancyGuard {
    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__NotTheAllowedToken();
    error DSCEngine__TheAddressListLengthNotMatch();
    error DSCEngine_TransferFromFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 userHeathFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsSafe(uint256 userHeathFactor);
    error DSCEngine__HealthFactorNotImproved();

    uint256 private constant ADDITIONAL_FEED_PRECISION_1e10 = 1e10;
    uint256 private constant PRECISION_1e18 = 1e18;
    uint256 private constant LIQUIDATION_RATIO_50 = 50;
    uint256 private constant LIQUIDATION_PRECISION_100 = 100;
    uint256 private constant MINIMUN_HEALTH_FACTOR_1e18 = 1e18;
    uint256 private constant LIQUIDATION_BONUS_10 = 10;
    mapping(address token => address priceFeed) private s_priceFeedsMap;
    mapping(address user => mapping(address token => uint256 amount)) private s_collatralDepositedMap;
    mapping(address user => uint256 amountDscMinted) private s_DscMintedMap;
    address[] private s_tokenCollateralAddrList;
    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////
    //  modifiers     //
    ////////////////////
    modifier onlyAmountMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier onlyAllowedToken(address _tokenAddr) {
        if (s_priceFeedsMap[_tokenAddr] == address(0)) {
            revert DSCEngine__NotTheAllowedToken();
        }
        _;
    }

    constructor(address[] memory tokenCollateralAddrList_, address[] memory priceFeedAddrList_, address DSCAddr_) {
        if (tokenCollateralAddrList_.length != priceFeedAddrList_.length) {
            revert DSCEngine__TheAddressListLengthNotMatch();
        }
        s_tokenCollateralAddrList = tokenCollateralAddrList_;
        for (uint256 i = 0; i < tokenCollateralAddrList_.length; i++) {
            s_priceFeedsMap[tokenCollateralAddrList_[i]] = priceFeedAddrList_[i];
        }
        i_dsc = DecentralizedStableCoin(DSCAddr_);
    }

    function depositCollateral(address _tokenCollateralAddr, uint256 _amountCollateral)
        public
        override
        onlyAmountMoreThanZero(_amountCollateral)
        onlyAllowedToken(_tokenCollateralAddr)
        nonReentrant
    {
        s_collatralDepositedMap[msg.sender][_tokenCollateralAddr] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddr, _amountCollateral);
        bool _success = IERC20(_tokenCollateralAddr).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!_success) {
            revert DSCEngine_TransferFromFailed();
        }
    }

    /**
     *
     * @param _acceptedToken  The address of the collateral token to deposit
     * @param _amountCollateral  The amount of collateral to deposit
     * @param _expectedMint  The amount of DSC to mint
     * @notice This function will deposit collateral and mint DSC
     */
    function depositCollateralAndMintDsc(address _acceptedToken, uint256 _amountCollateral, uint256 _expectedMint)
        public
        override
    {
        depositCollateral(_acceptedToken, _amountCollateral);
        mintDsc(_expectedMint);
    }

    /**
     *
     * @param _expectedToken  The address of the collateral token to redeem
     * @param _expectedCollateralAmount  The amount of collateral to redeem
     * @param _amountToBurn  The amount of DSC to burn
     * @notice This function will burn DSC and redeem collateral
     */
    function redeemCollateralForDsc(address _expectedToken, uint256 _expectedCollateralAmount, uint256 _amountToBurn)
        public
        override
    {
        burnDsc(_amountToBurn);
        // redeemCollateral(_expectedToken, _expectedCollateralAmount);
        _redeemCollateral(_expectedToken, _expectedCollateralAmount, msg.sender, msg.sender);
        _revertIfHeathFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address _expectedToken, uint256 _expectedCollateralAmount)
        public
        override
        onlyAmountMoreThanZero(_expectedCollateralAmount)
        nonReentrant
    {
        bool success = _redeemCollateral(_expectedToken, _expectedCollateralAmount, msg.sender, msg.sender);
        if (!success) {
            revert DSCEngine_TransferFromFailed();
        }
        _revertIfHeathFactorIsBroken(msg.sender);
    }

    /**
     *
     * @param _amountToBurn The amount of DSC to burn
     * @notice before we burn the DSC,we should get the DSC back from the user,oterwise the burned DSC is not the user's but the contract's
     */
    function burnDsc(uint256 _amountToBurn) public override onlyAmountMoreThanZero(_amountToBurn) {
        _burnDsc(_amountToBurn, msg.sender, msg.sender);
        _revertIfHeathFactorIsBroken(msg.sender); // actually,i don't think this would ever hit
    }

    /**
     *
     * @param _collateral  The address of the collateral token to liquidate
     * @param _liquidatedUser  The address of the user who has broken the heath factor to liquidate
     * @param _debtToCover The amount of DSC we want to burn to improve the user's heath factor
     * @dev When anyone else found a heath factor broken user,he can call this function to liquidate the broken user.
     * First,we will check if the user's heath factor is broken,if not,we will revert.
     * Second,we will calculate the amount of collateral which the msg.sender can get from the _debtToCover and add 10% bonus.The msg.sender wil get the amount from the _liquidatedUser who has broken the heath factor.
     * And the msg.sender just need to burn the _debtToCover DSC to improve the heath factor.
     */
    function liquidate(address _collateral, address _liquidatedUser, uint256 _debtToCover)
        public
        override
        onlyAmountMoreThanZero(_debtToCover)
        nonReentrant
    {
        uint256 startinguserHeathFactor = _healthFactor(_liquidatedUser);
        if (startinguserHeathFactor >= MINIMUN_HEALTH_FACTOR_1e18) {
            revert DSCEngine__HealthFactorIsSafe(startinguserHeathFactor);
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(_collateral, _debtToCover);
        uint256 bonusCollateral = tokenAmountFromDebtCovered * LIQUIDATION_BONUS_10 / LIQUIDATION_PRECISION_100; // addition 10% bonus
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(_collateral, totalCollateralToRedeem, _liquidatedUser, msg.sender);
        _burnDsc(_debtToCover, _liquidatedUser, msg.sender);
        uint256 endingUserHeathFactor = _healthFactor(_liquidatedUser);
        if (endingUserHeathFactor < MINIMUN_HEALTH_FACTOR_1e18) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHeathFactorIsBroken(msg.sender);
    }

    function mintDsc(uint256 _expectedMint) public override {
        s_DscMintedMap[msg.sender] += _expectedMint;
        _revertIfHeathFactorIsBroken(msg.sender);
        bool _success = i_dsc.mint(msg.sender, _expectedMint);
        if (!_success) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     *
     * @param _amountToBurn  The amount of DSC to burn
     * @param _onBehalfOf  The address of the user who's heath factor is broken and need to be liquidated
     * @param _dscFrom  The user who found the broken heath factor and want to liquidate the broken user
     * @dev Low-level internal function do not call unless the public function calling it is checking for heath factor being broken
     */
    function _burnDsc(uint256 _amountToBurn, address _onBehalfOf, address _dscFrom) internal {
        s_DscMintedMap[_onBehalfOf] -= _amountToBurn;
        bool success = IERC20(address(i_dsc)).transferFrom(_dscFrom, address(this), _amountToBurn); // get the dsc back,and at this line ,the dsc is not be burned yet
        if (!success) {
            // actually,this case will never happen,cuz the transferFrom will revert if the balance is not enough
            revert DSCEngine_TransferFromFailed();
        }
        i_dsc.burn(_amountToBurn); // at this line,the dsc is burned(and this dsc is from the _dscFrom)
    }

    function _redeemCollateral(address _expectedToken, uint256 _expectedCollateralAmount, address _from, address _to)
        internal
        returns (bool _success)
    {
        s_collatralDepositedMap[_from][_expectedToken] -= _expectedCollateralAmount; // the new version solidity will check the underflow and revert the wrong operation
        emit CollateralRedeemed(_from, _to, _expectedToken, _expectedCollateralAmount);
        (_success) = IERC20(_expectedToken).transfer(_to, _expectedCollateralAmount);
    }

    function _getAccountInformation(address _user)
        internal
        view
        returns (uint256 _totalDscMinted, uint256 _CollateralValueInUsd)
    {
        _totalDscMinted = s_DscMintedMap[_user];
        _CollateralValueInUsd = getAccountCollateralValue(_user);
    }

    function _revertIfHeathFactorIsBroken(address _user) internal view {
        uint256 _userHeathFactor = _healthFactor(_user);
        if (_userHeathFactor < MINIMUN_HEALTH_FACTOR_1e18) {
            revert DSCEngine__HealthFactorIsBroken(_userHeathFactor);
        }
    }

    function _healthFactor(address _user) internal view returns (uint256 _userHeathFactor) {
        (uint256 _totalDscMinted, uint256 _CollateralValueInUsd) = _getAccountInformation(_user);
        _userHeathFactor = _calculateHealthFactor(_totalDscMinted, _CollateralValueInUsd);
    }

    function _calculateHealthFactor(uint256 _totalDscMinted, uint256 _CollateralValueInUsd)
        internal
        pure
        returns (uint256 _userHeathFactor)
    {
        if (_totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForRatio = _CollateralValueInUsd * LIQUIDATION_RATIO_50 / LIQUIDATION_PRECISION_100;
        _userHeathFactor = collateralAdjustedForRatio * PRECISION_1e18 / _totalDscMinted;
    }

    ////////////////////
    // Getter Methods //
    ////////////////////

    function getTokenAmountFromUsd(address _collteral, uint256 _usdAmountInWei) public view returns (uint256 _amount) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(s_priceFeedsMap[_collteral]);
        (, int256 _price,,,) = _priceFeed.latestRoundData();
        _amount = _usdAmountInWei * PRECISION_1e18 / uint256(_price) / ADDITIONAL_FEED_PRECISION_1e10;
    }

    function priceFeeds(address _tokenAddr) public view returns (address _priceFeed) {
        _priceFeed = s_priceFeedsMap[_tokenAddr];
    }

    function dsc() public view returns (address _dsc) {
        _dsc = address(i_dsc);
    }

    function getAccountCollateralValue(address _user) public view returns (uint256 _totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_tokenCollateralAddrList.length; i++) {
            address _token = s_tokenCollateralAddrList[i];
            uint256 _amount = s_collatralDepositedMap[_user][_token];
            _totalCollateralValueInUsd += getUsdValue(_token, _amount);
        }
    }

    function getUsdValue(address _token, uint256 _amount) public view returns (uint256 _usdValue) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(s_priceFeedsMap[_token]);
        (, int256 _price,,,) = _priceFeed.latestRoundData();
        _usdValue = uint256(_price) * ADDITIONAL_FEED_PRECISION_1e10 * _amount / PRECISION_1e18;
    }

    function getTokenCollateralAddrList(uint256 _index) public view returns (address _collateral) {
        _collateral = s_tokenCollateralAddrList[_index];
    }

    function getAccountInformation(address _user)
        public
        view
        returns (uint256 _totalDscMinted, uint256 _CollateralValueInUsd)
    {
        (_totalDscMinted, _CollateralValueInUsd) = _getAccountInformation(_user);
    }

    function getDscMintedAmount(address _user) public view returns (uint256 _amount) {
        _amount = s_DscMintedMap[_user];
    }

    function getHealthFactor(address _user) public view returns (uint256 healthFactor) {
        healthFactor = _healthFactor(_user);
    }

    function getMinHealthFactor() external pure returns (uint256 _minimum) {
        _minimum = MINIMUN_HEALTH_FACTOR_1e18;
    }
}
