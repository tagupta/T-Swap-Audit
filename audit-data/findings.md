### [L-1] Unused custom error `PoolFactory__PoolDoesNotExist` in `PoolFactory` contract

**Description:**
The custom error `PoolFactory__PoolDoesNotExist` is defined in the `PoolFactory` contract but is never used.

**Impact:**
This could lead to confusion for developers reading the code, as it suggests that there is a specific error condition that can occur, but it is not actually being checked for or handled anywhere in the contract.

**Recommended Mitigation:**
Remove the unused error or implement checks for the error condition in the contract.

```diff
-        error PoolFactory__PoolDoesNotExist();
```

### [L-2] `wethToken` parameter in the constructor of the `PoolFactory` contract is not checked for zero address

**Description:**
The `wethToken` parameter in the constructor is not validated to ensure it is not a zero address.

**Impact:**
If a zero address is passed as the WETH token address, it could lead to unexpected behavior or vulnerabilities in the contract.

**Recommended Mitigation:**
Add a check in the constructor to ensure that the `wethToken` address is not the zero address.

```diff
+        require(wethToken != address(0), "WETH token address cannot be zero");
```

### [L-3] `liquidityTokenSymbol` variable of `PoolFactory::createPool` function should use `symbol()` instead of `name()`

**Description:**
The `liquidityTokenSymbol` variable is constructed using the `name()` function of the ERC20 token, but it should use the `symbol()` function instead to create a proper token symbol.

**Impact:**
Using the token name instead of the symbol could lead to incorrect or unexpected token symbols being generated for the liquidity tokens.

**Recommended Mitigation:**
Update the `liquidityTokenSymbol` variable to use the `symbol()` function of the ERC20 token instead of the `name()` function.

```diff
-        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```

### [L-4] `deadline` parameter in `TSwapPool::deposit` function is not used

**Description:**
The `deadline` parameter in the `deposit` function of the `TSwapPool` contract is not utilized within the function body.

**Impact:**
Having unused parameters can lead to confusion and may indicate incomplete functionality. It could also potentially waste gas if the parameter is not needed.

**Recommended Mitigation:**
Implement the logic in `deposit` function to utilize `deadline` parameter effectively.

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
+       uint64 deadline
    )
        external
        revertIfZero(wethToDeposit)
+       revertIfDeadlinePassed(deadline)
        returns (uint256 liquidityTokensToMint){
.
.
.
        }
```
