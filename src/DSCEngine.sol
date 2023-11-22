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

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_RATIO = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINIMUN_HEALTH_FACTOR = 1;
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

    function depositCollateralAndMintDsc() public override {}

    function redeemCollaternalForDsc() public override {}
    function redeemCollaternal() public override {}
    function burnDsc() public override {}
    function liquidate() public override {}

    function mintDsc(uint256 _amountCollatral) public override {
        s_DscMintedMap[msg.sender] += _amountCollatral;
    }

    function _getAccountInformation(address _user)
        internal
        view
        returns (uint256 _totalDscMinted, uint256 _collaternalValueInUsd)
    {
        _totalDscMinted = s_DscMintedMap[_user];
        _collaternalValueInUsd = getAccountCollateralValue(_user);
    }

    function _revertIfHeathFactorIsBroken(address _user) internal view {
        uint256 _userHeathFactor = _healthFactor(_user);
        if (_userHeathFactor < MINIMUN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(_userHeathFactor);
        }
    }

    function _healthFactor(address _user) internal view returns (uint256 _userHeathFactor) {
        (uint256 _totalDscMinted, uint256 _collaternalValueInUsd) = _getAccountInformation(_user);
        uint256 collateralAdjustedForRatio = _collaternalValueInUsd * LIQUIDATION_RATIO / LIQUIDATION_PRECISION;
        _userHeathFactor = collateralAdjustedForRatio * PRECISION / _totalDscMinted;
    }

    ////////////////////
    // Getter Methods //
    ////////////////////
    function getHealthFactor() public view override returns (uint256 healthFactor) {}

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
        _usdValue = uint256(_price) * ADDITIONAL_FEED_PRECISION * _amount / PRECISION;
    }
}
