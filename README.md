# DEFI-stablecoin

## For development

> It is essential to consider precision in all computations due to the employment of Wei as the standard unit for contract interaction on the Ethereum network. Notably, 1 ether is equal to 1 * 1e18 Wei or 1 * 1e9 GWei. Therefore, it is necessary to maintain consistent units when performing calculations.

1. In the constructor, it is necessary to predefine the supported types of collateral tokens and obtain the addresses of the corresponding Price Feed contracts. Additionally, our DSC token is initialized.

2. The initial interaction expected from users is to deposit their collateral tokens within our contract.

3. We need to acquire the USD price of the respective collateral tokens by utilizing Chainlink's Price Feed.

4. Concerning the health factor: Accounts that fall below the minimum health factor are eligible for liquidation. It is crucial to ensure that the total value of collateral tokens consistently surpasses the total value of held DSC tokens. Specifically, the value of collateral tokens must always exceed the value of DSC tokens. In our contract, the health factor has been set at 50% (LIQUIDATION_RATIO). Consequently, only when the value of collateral tokens reaches 200% of the value of DSC tokens will the health factor exceed the minimum threshold (MINIMUM_HEALTH_FACTOR = 1).


### Test Part

1. **Unit Test**
Test result: ok. 23 passed; 0 failed; 0 skipped;(23 total tests)
# defi-stablecoin
