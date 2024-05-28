// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseHook} from "lib/v4-periphery/contracts/BaseHook.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "lib/v4-periphery/lib/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/contracts/types/PoolKey.sol";
import {BalanceDelta} from "lib/v4-periphery/lib/v4-core/contracts/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArbitrageHook is BaseHook {
    using SafeERC20 for IERC20;

    struct ArbitrageOpportunity {
        address poolA;
        address poolB;
        uint256 profit;
    }

    address public owner;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: false,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
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

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata data
    ) external override returns (bytes4) {
        // Decode arbitrage opportunity from data
        ArbitrageOpportunity memory opportunity = abi.decode(data, (ArbitrageOpportunity));

        // Execute arbitrage if profitable
        if (opportunity.profit > 0) {
            executeArbitrage(key, swapParams, opportunity);
        }

        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta calldata balanceDelta,
        bytes calldata data
    ) external override returns (bytes4) {
        // Handle after swap logic
        return BaseHook.afterSwap.selector;
    }

    function getPrice(PoolKey memory key, uint256 amountIn) public view returns (uint256 amountOut, uint256 price) {
        // Get the price of the token in the pool
        (uint160 sqrtPriceX96, , ,) = poolManager.getSlot0(key.toId());
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**96);
        amountOut = amountIn * price / (10**18);
    }

    function executeArbitrage(
        PoolKey memory key,
        IPoolManager.SwapParams memory swapParams,
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

    function addLiquidity(
        address token,
        uint256 amount
    ) public onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(poolManager), amount);
    }

    function withdraw(
        address token,
        uint256 amount
    ) public onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
