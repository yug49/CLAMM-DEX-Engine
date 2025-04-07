// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./TickMath.sol";

library Tick {
    error TICK__LiquidityGrossOverflow();

    struct Info {
        uint128 liquidityGross;
        // Amount of liquidity to add / sub when tick is crossed
        // +  when tick crosses from left to right
        // -  when tick crosses from right to left
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialize;
    }

    function update(
        mapping(int24 => Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper, // true if updating position's upper tick
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = liquidityDelta < 0
            ? liquidityGrossBefore - uint128(-liquidityDelta)
            : liquidityGrossBefore + uint128(liquidityDelta);

        if(liquidityGrossAfter > maxLiquidity) {
            revert TICK__LiquidityGrossOverflow();
        }
        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if(liquidityGrossBefore == 0) {
            if(tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
            info.initialize = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        info.liquidityNet = upper
            ? info.liquidityNet + liquidityDelta
            : info.liquidityNet - liquidityDelta;
    }
    function cross(
        mapping(int24 => Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns(int128 liquidityNet) {
        Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        liquidityNet = info.liquidityNet;
    }

    function clear(mapping(int24 => Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }
}