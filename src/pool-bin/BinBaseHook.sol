// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    HOOKS_BEFORE_INITIALIZE_OFFSET,
    HOOKS_AFTER_INITIALIZE_OFFSET,
    HOOKS_BEFORE_MINT_OFFSET,
    HOOKS_AFTER_MINT_OFFSET,
    HOOKS_BEFORE_BURN_OFFSET,
    HOOKS_AFTER_BURN_OFFSET,
    HOOKS_BEFORE_SWAP_OFFSET,
    HOOKS_AFTER_SWAP_OFFSET,
    HOOKS_BEFORE_DONATE_OFFSET,
    HOOKS_AFTER_DONATE_OFFSET,
    HOOKS_NO_OP_OFFSET
} from "@pancakeswap/v4-core/src/pool-bin/interfaces/IBinHooks.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {IVault} from "@pancakeswap/v4-core/src/interfaces/IVault.sol";
import {IBinHooks} from "@pancakeswap/v4-core/src/pool-bin/interfaces/IBinHooks.sol";
import {IBinPoolManager} from "@pancakeswap/v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {BinPoolManager} from "@pancakeswap/v4-core/src/pool-bin/BinPoolManager.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract BinBaseHook is IBinHooks {
    using SafeERC20 for IERC20;

    error NotPoolManager();
    error NotVault();
    error NotSelf();
    error InvalidPool();
    error LockFailure();
    error HookNotImplemented();

    struct Permissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeMint;
        bool afterMint;
        bool beforeBurn;
        bool afterBurn;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool noOp;
    }

    struct ArbitrageOpportunity {
        address poolA;
        address poolB;
        uint256 profit;
    }

    /// @notice The address of the pool manager
    IBinPoolManager public immutable poolManager;

    /// @notice The address of the vault
    IVault public immutable vault;

    constructor(IBinPoolManager _poolManager) {
        poolManager = _poolManager;
        vault = BinPoolManager(address(poolManager)).vault();
    }

    /// @dev Only the pool manager may call this function
    modifier poolManagerOnly() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @dev Only the vault may call this function
    modifier vaultOnly() {
        if (msg.sender != address(vault)) revert NotVault();
        _;
    }

    /// @dev Only this address may call this function
    modifier selfOnly() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    /// @dev Only pools with hooks set to this contract may call this function
    modifier onlyValidPools(IHooks hooks) {
        if (address(hooks) != address(this)) revert InvalidPool();
        _;
    }

    /// @dev Helper function when the hook needs to get a lock from the vault. See
    ///      https://github.com/pancakeswap/pancake-v4-hooks oh hooks which perform vault.lock()
    function lockAcquired(bytes calldata data) external virtual vaultOnly returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).call(data);
        if (success) return returnData;
        if (returnData.length == 0) revert LockFailure();
        // if the call failed, bubble up the reason
        /// @solidity memory-safe-assembly
        assembly {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    function beforeInitialize(address, PoolKey calldata, uint24, bytes calldata) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterInitialize(address, PoolKey calldata, uint24, bytes calldata) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    function beforeMint(address, PoolKey calldata, IBinPoolManager.MintParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterMint(address, PoolKey calldata, IBinPoolManager.MintParams calldata, BalanceDelta, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeBurn(address, PoolKey calldata, IBinPoolManager.BurnParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterBurn(address, PoolKey calldata, IBinPoolManager.BurnParams calldata, BalanceDelta, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeSwap(address, PoolKey calldata, bool, uint128, bytes calldata) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterSwap(address, PoolKey calldata, bool, uint128, BalanceDelta, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function _hooksRegistrationBitmapFrom(Permissions memory permissions) internal pure returns (uint16) {
        return uint16(
            (permissions.beforeInitialize ? 1 << HOOKS_BEFORE_INITIALIZE_OFFSET : 0)
                | (permissions.afterInitialize ? 1 << HOOKS_AFTER_INITIALIZE_OFFSET : 0)
                | (permissions.beforeMint ? 1 << HOOKS_BEFORE_MINT_OFFSET : 0)
                | (permissions.afterMint ? 1 << HOOKS_AFTER_MINT_OFFSET : 0)
                | (permissions.beforeBurn ? 1 << HOOKS_BEFORE_BURN_OFFSET : 0)
                | (permissions.afterBurn ? 1 << HOOKS_AFTER_BURN_OFFSET : 0)
                | (permissions.beforeSwap ? 1 << HOOKS_BEFORE_SWAP_OFFSET : 0)
                | (permissions.afterSwap ? 1 << HOOKS_AFTER_SWAP_OFFSET : 0)
                | (permissions.beforeDonate ? 1 << HOOKS_BEFORE_DONATE_OFFSET : 0)
                | (permissions.afterDonate ? 1 << HOOKS_AFTER_DONATE_OFFSET : 0)
                | (permissions.noOp ? 1 << HOOKS_NO_OP_OFFSET : 0)
        );
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
        IBinPoolManager.SwapParams memory swapParams,
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
