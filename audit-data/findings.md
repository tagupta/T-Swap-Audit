### [M-1] `TSwapPool::deposit` is missing a `deadline` parameter check causing transactions to be processed after the deadline

**Description:**
The `TSwapPool::deposit` function in the `TSwapPool` contract includes a `deadline` parameter which according to the documentation is **The deadline for the transaction to be completed by**, but there is no check to ensure that the transaction is processed before the deadline. This could allow users to execute **add liquidity** transactions at an unexpected time, leading to potential loss of funds when the deposit rate in unfavorable.

<!-- MEV attacks -->

**Impact:** Transactions could be sent when market conditions are unfavourable to deposit even after adding a deadline parameter to the function without checking it could lead to unexpected behavior and potential loss of funds.

**Proof of Concept:** The `deadline` parameter is unused.

**Recommended Mitigation:** Consider making the following changes to the function.

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
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

### [L-1] The arguments set for this event `TSwapPool::LiquidityAdded` are not correct

**Description:** The event `LiquidityAdded` is emitting the wrong arguments. The order of the arguments should be `wethDeposited` first, then `poolTokensDeposited`.

```javascript
//event definition
event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
```

```javascript
//event emission
emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
```

**Impact:** This could lead to confusion for developers reading the code, as it suggests that there is a specific error condition that can occur, but it is not actually being checked for or handled anywhere in the contract.

**Recommended Mitigation:**
Change the order of the arguments in the event definition and the event emission to match the correct order.

```diff
-    event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
+    event LiquidityAdded(address indexed liquidityProvider, uint256 poolTokensDeposited, uint256 wethDeposited);
```

### [I-1] Unused custom error `PoolFactory::PoolFactory__PoolDoesNotExist` in `PoolFactory` contract

**Description:**
The custom error `PoolFactory__PoolDoesNotExist` is defined in the `PoolFactory` contract but is never used.

**Impact:**
This could lead to confusion for developers reading the code, as it suggests that there is a specific error condition that can occur, but it is not actually being checked for or handled anywhere in the contract.

**Recommended Mitigation:**
Remove the unused error or implement checks for the error condition in the contract.

```diff
-        error PoolFactory__PoolDoesNotExist();
```

### [I-2] `wethToken` parameter in the constructor of the `PoolFactory` contract is not checked for zero address

**Description:**
The `wethToken` parameter in the constructor is not validated to ensure it is not a zero address.

**Impact:**
If a zero address is passed as the WETH token address, it could lead to unexpected behavior or vulnerabilities in the contract.

**Recommended Mitigation:**
Add a check in the constructor to ensure that the `wethToken` address is not the zero address.

```diff
+        require(wethToken != address(0), "WETH token address cannot be zero");
```

### [I-3] `liquidityTokenSymbol` variable of `PoolFactory::createPool` function should use `symbol()` instead of `name()`

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

### [I-4] `deadline` parameter in `TSwapPool::deposit` function is not used

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

### [I-5]: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

```diff
-            event PoolCreated(address tokenAddress, address poolAddress);
+            event PoolCreated(address indexed tokenAddress, address indexed poolAddress);
```

```diff
-            event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
+            event LiquidityAdded(address indexed liquidityProvider, uint256 indexed wethDeposited, uint256 indexed poolTokensDeposited);
```

```diff
-            event LiquidityRemoved(address indexed liquidityProvider, uint256 wethWithdrawn, uint256 poolTokensWithdrawn);
+            event LiquidityRemoved(address indexed liquidityProvider, uint256 indexed wethWithdrawn, uint256 indexed poolTokensWithdrawn);
```

```diff
-            event Swap(address indexed swapper, IERC20 tokenIn, uint256 amountTokenIn, IERC20 tokenOut, uint256 amountTokenOut);
+            event Swap(address indexed swapper, IERC20 indexed tokenIn, uint256 amountTokenIn, IERC20 indexed tokenOut, uint256 amountTokenOut);
```

<details><summary>4 Found Instances</summary>

- Found in src/PoolFactory.sol [Line: 35](../src/PoolFactory.sol#L35)

```solidity
        event PoolCreated(address tokenAddress, address poolAddress);
```

- Found in src/TSwapPool.sol [Line: 43](../src/TSwapPool.sol#L43)

```solidity
        event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
```

- Found in src/TSwapPool.sol [Line: 44](../src/TSwapPool.sol#L44)

```solidity
        event LiquidityRemoved(address indexed liquidityProvider, uint256 wethWithdrawn, uint256 poolTokensWithdrawn);
```

- Found in src/TSwapPool.sol [Line: 45](../src/TSwapPool.sol#L45)

```solidity
        event Swap(address indexed swapper, IERC20 tokenIn, uint256 amountTokenIn, IERC20 tokenOut, uint256 amountTokenOut);
```

</details>

### [I-6] `TSwapPool::TSwapPool__WethDepositAmountTooLow` in this event, `TSwapPool::MINIMUM_WETH_LIQUIDITY` is not required to be emitted as this a constant value

**Description:**
The event `TSwapPool::TSwapPool__WethDepositAmountTooLow` emits the constant value `TSwapPool::MINIMUM_WETH_LIQUIDITY`, which is unnecessary.

**Impact:**
Unnecessary emissions can lead to increased gas costs and cluttered event logs, making it harder for off-chain tools to parse relevant information.

**Recommended Mitigation:**
Remove the emission of `TSwapPool::MINIMUM_WETH_LIQUIDITY` from the event `TSwapPool::TSwapPool__WethDepositAmountTooLow`.

```diff
-        error TSwapPool__WethDepositAmountTooLow(uint256 minimumWethDeposit, uint256 wethToDeposit);
+        error TSwapPool__WethDepositAmountTooLow(uint256 wethToDeposit);
```

```diff
-        revert TSwapPool__WethDepositAmountTooLow(MINIMUM_WETH_LIQUIDITY, wethToDeposit);
+        revert TSwapPool__WethDepositAmountTooLow(wethToDeposit);
```

### [I-7] `TSwapPool::deposit` function is not following CEI for the first-time liquidity deposit

**Description:** The `TSwapPool::deposit` function does not follow the Checks-Effects-Interactions (CEI) pattern for the first-time liquidity deposit. Specifically, it performs state changes (effects) after interations, which can lead to unexpected behavior and vulnerabilities.

**Impact:** This can lead to reentrancy attacks or other unexpected behaviors, especially if the contract interacts with external contracts or tokens.

**Recommended Mitigation:**
Ensure that the function follows the CEI pattern by performing all checks first, then making state changes, and finally interacting with external contracts or tokens.

```diff
        else {
+       liquidityTokensToMint = wethToDeposit;
        _addLiquidityMintAndTransfer(wethToDeposit, maximumPoolTokensToDeposit, wethToDeposit);
-       liquidityTokensToMint = wethToDeposit;
        }
```

### [I-8] Usage of magic numbers such as 997 and 1000 is not recommended

**Description:**
Magic numbers are hard-coded values that appear in code without explanation. They can make code difficult to understand and maintain.

```javascript
        uint256 inputAmountMinusFee = inputAmount * 997;
        uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
```

**Impact:** Using magic numbers can lead to confusion and errors, as the meaning of these numbers is not immediately clear. It can also make future modifications more difficult.

**Recommended Mitigation:**
Define constants for these magic numbers to improve code readability and maintainability.

```diff
+       uint256 constant FEE_DENOMINATOR = 1000;
+       uint256 constant FEE_MULTIPLIER = 997;
        uint256 inputAmountMinusFee = inputAmount * FEE_MULTIPLIER;
        uint256 denominator = (inputReserves * FEE_DENOMINATOR) + inputAmountMinusFee;
```

### [I-9] Natspec is not defined for the function `TSwapPool::swapExactInput`

**Description:** The function `TSwapPool::swapExactInput` does not have Natspec comments defined, which are used to provide documentation for functions, parameters, and return values.

**Impact:** Without Natspec comments, it is difficult for developers to understand the purpose and usage of the function, which can lead to misuse or errors.

**Recommended Mitigation:**
Add Natspec comments to the function to provide clear documentation for its purpose, parameters, and return values.

```diff
+    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
+    /// @param inputToken The address of the input token
+    /// @param inputAmount The exact amount of input tokens to swap
+    /// @param outputToken The address of the output token
+    /// @param minOutputAmount The minimum amount of output tokens to receive
+    /// @param deadline The deadline for the transaction to be completed by
+    /// @return amountOut The amount of output tokens received
        function swapExactInput(
                IERC20 inputToken,
                uint256 inputAmount,
                IERC20 outputToken,
                uint256 minOutputAmount,
                uint64 deadline
        ) external returns (uint256 amountOut) {
                // Swap logic here
        }
```

### [I-10] `TSwapPool::swapExactOutput` natspec is missing the `@param` tag for `deadline`

**Description:**
The `@param` tag for `deadline` is missing in the Natspec comments for the `TSwapPool::swapExactOutput` function.

**Impact:**
Without the `@param` tag, users may not understand the purpose of the `deadline` parameter, leading to potential misuse or errors.

**Recommended Mitigation:**
Add the `@param` tag for `deadline` in the Natspec comments for the `TSwapPool::swapExactOutput` function.

```diff
+   /// @param deadline The deadline for the transaction to be completed by
    /// @return amountIn The amount of input tokens used for the swap
    function swapExactOutput(
        IERC20 inputToken,
        uint256 outputAmount,
        IERC20 outputToken,
        uint256 maxInputAmount,
        uint64 deadline
    )
        external
        revertIfZero(outputAmount)
        revertIfDeadlinePassed(deadline)
        returns (uint256 amountIn)
    {        // Swap logic here
    }
```

### [G-1] `TSwapPool::swapExactInput` and `TSwapPool::totalLiquidityTokenSupply` functions should be marked as `external` instead of `public`

**Description:** The `TSwapPool::swapExactInput` and `TSwapPool::totalLiquidityTokenSupply` functions are currently marked as `public`, but they should be marked as `external` to optimize gas usage and restrict access to external calls only.

**Impact:** Marking the function as `external` can reduce gas costs by allowing the Solidity compiler to optimize the function call.

**Recommended Mitigation:**
Change the visibility of the `swapExactInput` function from `public` to `external`.

```diff
    function swapExactInput(
        IERC20 inputToken,
        uint256 inputAmount,
        IERC20 outputToken,
        uint256 minOutputAmount,
        uint64 deadline
    )
-    public returns (uint256 amountOut) {
+    external returns (uint256 amountOut) {
        // Swap logic here
    }
```

Change the visibility of the `totalLiquidityTokenSupply` function from `public` to `external`.

```diff
    function totalLiquidityTokenSupply()
-    public view returns (uint256) {
+    external view returns (uint256) {
        return totalSupply();
    }
```
