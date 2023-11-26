// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Script.sol";

/**
 * @title DecentralizedStableCoin
 * @author GrayJiang
 * @notice Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
 * @dev This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__BurnAmountNegative();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__TransferToZeroAddress();

    constructor(address _initialOwner) ERC20("DecentralizedStableCoin", "DSC") Ownable(_initialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount < 0) {
            revert DecentralizedStableCoin__BurnAmountNegative();
        }
        uint256 balance = balanceOf(msg.sender);
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount); // because we override the burn function, we need to call the original burn function
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__TransferToZeroAddress();
        }
        if (_amount < 0) {
            revert DecentralizedStableCoin__BurnAmountNegative();
        }
        _mint(_to, _amount);
        return true;
    }
}
