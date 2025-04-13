// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {CLAMMPool} from "../src/CLAMMPool.sol";
import {CLAMMPoolDeployer} from "./CLAMMPoolDeployer.s.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

/**
 * Position Management
 */
contract AddLiquidity is Script {
    function run(int24 tickLower, int24 tickUpper, uint128 amount) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

        vm.startBroadcast();
        // Add liquidity to the pool
        clammPool.mint(msg.sender, tickLower, tickUpper, amount);
        vm.stopBroadcast();
    }
}

contract RemoveLiquidity is Script {
    function run(int24 tickLower, int24 tickUpper, uint128 amount) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

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
    function run(int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

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
    function run(uint256 amount, uint160 sqrtPriceLimitX96) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, true, int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensOneForZeroExactInput is Script {
    function run(uint256 amount, uint160 sqrtPriceLimitX96) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, false, int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensZeroForOneExactOutput is Script {
    function run(uint256 amount, uint160 sqrtPriceLimitX96) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, true, -int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}

contract SwapTokensOneForZeroExactOutput is Script {
    function run(uint256 amount, uint160 sqrtPriceLimitX96) public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("CLAMMPool", block.chainid);
        CLAMMPool clammPool = CLAMMPool(recentDeployment);

        vm.startBroadcast();
        // Swap tokens in the pool
        clammPool.swap(msg.sender, false, -int256(amount), sqrtPriceLimitX96, bytes("0x"));
        vm.stopBroadcast();
    }
}
