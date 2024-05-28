// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./CLBaseHook.sol";

/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract CLCounterHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public afterAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {}

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                noOp: false
            })
        );
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override poolManagerOnly returns (bytes4) {
        beforeAddLiquidityCount[key.toId()]++;
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override poolManagerOnly returns (bytes4) {
        afterAddLiquidityCount[key.toId()]++;
        return this.afterAddLiquidity.selector;
    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        beforeSwapCount[key.toId()]++;
        return this.beforeSwap.selector;
    }

    function afterSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        afterSwapCount[key.toId()]++;

        // Check for arbitrage opportunities and execute if profitable
        ArbitrageOpportunity memory opportunity = checkArbitrageOpportunity(key, key, 1000); // Example values
        if (opportunity.profit > 0) {
            executeArbitrage(key, ICLPoolManager.SwapParams({zeroForOne: true, amountSpecified: 1000}), opportunity);
        }

        return this.afterSwap.selector;
    }

    function checkArbitrageOpportunity(
        PoolKey memory keyA,
        PoolKey memory keyB,
        uint256 amountIn
    ) public view returns (ArbitrageOpportunity memory) {
        // Get prices from both pools
        (uint256 priceA,) = getPrice(keyA, amountIn);
        (uint256 priceB,) = getPrice(keyB, amountIn);

        // Determine profit if any
        uint256 profit = 0;
        if (priceA > priceB) {
            profit = priceA - priceB;
        } else if (priceB > priceA) {
            profit = priceB - priceA;
        }

        return ArbitrageOpportunity({
            poolA: address(poolManager),
            poolB: address(poolManager),
            profit: profit
        });
    }

    function getPrice(PoolKey memory key, uint256 amountIn) public view returns (uint256 amountOut, uint256 price) {
        // Get the price of the token in the pool
        (uint160 sqrtPriceX96, , ,) = poolManager.getSlot0(key.toId());
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**96);
        amountOut = amountIn * price / (10**18);
    }

    function executeArbitrage(
        PoolKey memory key,
        ICLPoolManager.SwapParams memory swapParams,
        ArbitrageOpportunity memory opportunity
    ) internal {
        // Execute arbitrage trade
        // Assume we swap from poolA to poolB
        // Swap on pool A
        (uint256 amountOutA, ) = poolManager.swap(key, swapParams, "");

        // Swap on pool B
        swapParams.zeroForOne = !swapParams.zeroForOne;
        swapParams.amountSpecified = int256(amountOutA);
        poolManager.swap(key, swapParams, "");
    }
}
