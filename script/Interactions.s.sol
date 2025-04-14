// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {CLAMMPool} from "../src/CLAMMPool.sol";
import {CLAMMPoolDeployer} from "./CLAMMPoolDeployer.s.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

// Deployed EURC/USDC pool on sepolia ethereum
address constant POOL_ADDRESS = 0x5382fEdC620Ae75d977625fee04b0e9a13346bff;

/**
 * Position Management
 */
contract AddLiquidity is Script {
    function run() public {
        int24 tickLower = int24(vm.envInt("LOWER_TICK"));
        int24 tickUpper = int24(vm.envInt("UPPER_TICK"));
        uint128 amount = uint128(vm.envUint("AMOUNT_TO_ADD"));
        address token0 = vm.envAddress("TOKEN_A");
        address token1 = vm.envAddress("TOKEN_B");

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Add liquidity to the pool
        IERC20(token0).approve(POOL_ADDRESS, amount);
        IERC20(token1).approve(POOL_ADDRESS, amount);

        clammPool.mint(msg.sender, tickLower, tickUpper, amount);
        vm.stopBroadcast();
    }
}

contract RemoveLiquidity is Script {
    function run() public {
        int24 tickLower = int24(vm.envInt("LOWER_TICK"));
        int24 tickUpper = int24(vm.envInt("UPPER_TICK"));
        uint128 amount = uint128(vm.envUint("AMOUNT_TO_REMOVE"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Remove liquidity from the pool
        clammPool.burn(tickLower, tickUpper, amount);
        vm.stopBroadcast();
    }
}

/**
 * Collect Fees or Removed/Burned Liquidity
 */
contract CollectFeesAndRemovedLiquidity is Script {
    function run() public {
        int24 tickLower = int24(vm.envInt("LOWER_TICK"));
        int24 tickUpper = int24(vm.envInt("UPPER_TICK"));
        uint128 amount0Requested = uint128(vm.envUint("AMOUNT0_TO_COLLECT"));
        uint128 amount1Requested = uint128(vm.envUint("AMOUNT1_TO_COLLECT"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Collect fees and removed liquidity
        clammPool.collect(msg.sender, tickLower, tickUpper, amount0Requested, amount1Requested);
        vm.stopBroadcast();
    }
}

/**
 * Swap Management
 */
contract SwapTokensZeroForOneExactInput is Script {
    function run() public {
        uint256 amount = uint256(vm.envUint("SWAP_AMOUNT"));
        uint160 sqrtPriceLimitX96 = uint160(vm.envUint("SQRT_PRICE_LIMIT_X96"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, true, int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensOneForZeroExactInput is Script {
    function run() public {
        uint256 amount = uint256(vm.envUint("SWAP_AMOUNT"));
        uint160 sqrtPriceLimitX96 = uint160(vm.envUint("SQRT_PRICE_LIMIT_X96"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, false, int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensZeroForOneExactOutput is Script {
    function run() public {
        uint256 amount = uint256(vm.envUint("SWAP_AMOUNT"));
        uint160 sqrtPriceLimitX96 = uint160(vm.envUint("SQRT_PRICE_LIMIT_X96"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, true, -int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensOneForZeroExactOutput is Script {
    function run() public {
        uint256 amount = uint256(vm.envUint("SWAP_AMOUNT"));
        uint160 sqrtPriceLimitX96 = uint160(vm.envUint("SQRT_PRICE_LIMIT_X96"));

        CLAMMPool clammPool = CLAMMPool(POOL_ADDRESS);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, false, -int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}
