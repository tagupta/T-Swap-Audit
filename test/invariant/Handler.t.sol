// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { PoolFactory } from "src/PoolFactory.sol";
import { TSwapPool } from "src/TSwapPool.sol";

contract Handler is Test {
    TSwapPool immutable i_tswapPool;
    ERC20Mock weth;
    ERC20Mock poolToken;
    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");
    
    // ghost variables to track deltas
    int256 startingX; //Pool token / ERC20 - X
    int256 startingY; //weth

    int256 endingX; //Pool token / ERC20 - X
    int256 endingY; //weth

    int256 public expectedDeltaX; //poolToken
    int256 public expectedDeltaY; //weth

    int256 public actualDeltaX; //poolToken
    int256 public actualDeltaY; //weth

    constructor(TSwapPool _tswapPool) {
        i_tswapPool = _tswapPool;
        weth = ERC20Mock(_tswapPool.getWeth());
        poolToken = ERC20Mock(_tswapPool.getPoolToken());
    }

    //add liquidity
    function depositTokens(uint256 wethAmount) external {
        wethAmount = bound(wethAmount, i_tswapPool.getMinimumWethDepositAmount(), type(uint64).max);

        _updateStartingDeltas(int256(wethAmount), int256(i_tswapPool.getPoolTokensToDepositBasedOnWeth(wethAmount)));

        //deposit tokens into the pool
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));

        poolToken.approve(address(i_tswapPool), type(uint256).max);
        weth.approve(address(i_tswapPool), type(uint256).max);

        i_tswapPool.deposit(wethAmount, 0, uint256(expectedDeltaX), 0);
        vm.stopPrank();

        _updateEndingDeltas();
    }

    function swapPoolTokensForWethBasedOnOutputWeth(uint256 outputWeth) external {
        outputWeth = bound(outputWeth, 1, weth.balanceOf(address(i_tswapPool)) - 1);
        //do not swap if this amount is too high
        if (outputWeth > weth.balanceOf(address(i_tswapPool))) return;

        uint256 inputReserve_PoolToken = poolToken.balanceOf(address(i_tswapPool));
        uint256 outputReserve_Weth = weth.balanceOf(address(i_tswapPool));

        uint256 poolTokenToDeposit =
            i_tswapPool.getInputAmountBasedOnOutput(outputWeth, inputReserve_PoolToken, outputReserve_Weth); //DeltaX

        if (poolTokenToDeposit > type(uint64).max) return; //prevent overflow

        _updateStartingDeltas(int256(outputWeth) * int256(-1), int256(poolTokenToDeposit));

        //mint pool tokens to the user if user balance is not enough
        if (poolToken.balanceOf(user) < poolTokenToDeposit) {
            poolToken.mint(user, poolTokenToDeposit - poolToken.balanceOf(user) + 1); //just to be sure
        }
        vm.startPrank(user);

        //user will swap those pool tokens for weth
        poolToken.approve(address(i_tswapPool), type(uint256).max);
        i_tswapPool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));

        vm.stopPrank();
        _updateEndingDeltas();
    }

    function _updateStartingDeltas(int256 wethAmount, int256 poolTokenAmount) internal {
        startingX = int256(poolToken.balanceOf(address(i_tswapPool)));
        startingY = int256(weth.balanceOf(address(i_tswapPool)));

        expectedDeltaX = int256(poolTokenAmount);
        expectedDeltaY = int256(wethAmount);
    }

    function _updateEndingDeltas() internal {
        endingX = int256(poolToken.balanceOf(address(i_tswapPool)));
        endingY = int256(weth.balanceOf(address(i_tswapPool)));

        actualDeltaX = endingX - startingX;
        actualDeltaY = endingY - startingY;
    }
}
