// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { PoolFactory } from "src/PoolFactory.sol";
import { TSwapPool } from "src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { Handler } from "./Handler.t.sol";
import { TransferFeeToken } from "../mocks/TransferFeeToken.sol";

contract InvariantWeirdTokenTest is StdInvariant, Test {
    PoolFactory poolFactory;
    TSwapPool tSwapPool;
    TransferFeeToken poolToken;
    ERC20Mock weth;

    int256 constant INITIAL_AMOUNT_X = 100e18; //Pool token / ERC20 - X
    int256 constant INITIAL_AMOUNT_Y = 50e18; // WETH - Y
    Handler handler;

    function setUp() external {
        poolToken = new TransferFeeToken(1e15, "Weird ERC20", "wERC20");
        weth = new ERC20Mock();

        poolFactory = new PoolFactory(address(weth));

        tSwapPool = TSwapPool(poolFactory.createPool(address(poolToken)));
        
        poolToken.mint(address(this), uint256(INITIAL_AMOUNT_X));
        weth.mint(address(this), uint256(INITIAL_AMOUNT_Y));

        poolToken.approve(address(tSwapPool), type(uint256).max);
        weth.approve(address(tSwapPool), type(uint256).max);

        tSwapPool.deposit(
            uint256(INITIAL_AMOUNT_Y), uint256(INITIAL_AMOUNT_Y), uint256(INITIAL_AMOUNT_X), uint64(block.timestamp)
        );

        handler = new Handler(tSwapPool);

        bytes4[] memory targetSelectors = new bytes4[](2);
        targetSelectors[0] = handler.depositTokens.selector;
        targetSelectors[1] = handler.swapPoolTokensForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector(address(handler), targetSelectors));
        targetContract(address(handler));
    }

    function invariant_constantProductFormulaStaysTheSameX() external view {
        assertEq(handler.expectedDeltaX(), handler.actualDeltaX(), "Delta X mismatch");
    }

    function invariant_constantProductFormulaStaysTheSameY() external view {
        assertEq(handler.expectedDeltaY(), handler.actualDeltaY(), "Delta Y mismatch");
    }
}
