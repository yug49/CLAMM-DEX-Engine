// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./FullMath.sol";
import "./SqrtPriceMath.sol";

library SwapMath {
    /**
     *
     * @param sqrtRatioCurrentX96 sqrt price of the current tick
     * @param sqrtRatioTargetX96 sqrt price of the target tick
     * @param liquidity liquidity of the current tick
     * @param amountRemaining amount remaining after the last swap
     * @param feePips fee in pips (1e6 = 100%, 1/100 of a bip)
     * @return sqrtRatioNextX96 sqrt price of the after the swap
     * @return amountIn amount in to swap, it it in terms of token0 if zeroForOne is true, otherwise it is in terms of token1
     * @return amountOut amount out to swap, it it in terms of token0 if zeroForOne is false, otherwise it is in terms of token1
     * @return feeAmount fee amount in terms of token0 if zeroForOne is true, otherwise it is in terms of token1
     */
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        // 1bip = 1/100 * 1% = 1/1e4
        // 1e6 = 100%, 1/100 of a bip
        uint24 feePips // feePips = 1 => 1/100 of a bip
    ) internal pure returns (uint160 sqrtRatioNextX96, uint256 amountIn, uint256 amountOut, uint256 feeAmount) {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96; // true if the swap is in the direction of token0 to token1
        bool exactIn = amountRemaining > 0; // true if the swap is exact in, false if it is exact out - exact in is when the user specifies the amount of token0/token1 to swap, exact out is when the user specifies the amount of token1/token0 to receive

        //Calcute max amountIn or amountOut and next sqrt ratio
        if (exactIn) {
            uint256 amountInRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);

            // Calculate max amountIn and, round up amountIn
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);

            // calculate next sqrt ratio
            if (amountInRemainingLessFee >= amountIn) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96, liquidity, amountInRemainingLessFee, zeroForOne
                );
            }
        } else {
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false);
            // calculate next sqrt ratio
            if (uint256(-amountRemaining) >= amountOut) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96, liquidity, uint256(-amountRemaining), zeroForOne
                );
            }
        }

        // calculate amountIn and amountOut bwteen sqrt current and next
        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;
        if (zeroForOne) {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        // calculate fee on amountIn
        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            // we didn't reach the targe, so take the remainder of the maximum input as fee
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            // either one of
            // - Not exact input
            // - Exact input and sqrt tatio next = target

            // a = amount in
            // f = feePips
            // x = amount in + fee
            // fee = x*f

            // Solve for x
            // x = a + fee = a + x*f
            // x(1 - f) = a
            // x = a / (1 - f)
            // fee = x*f = a*f / (1 - f)

            // fee = amountIn * f / (1e6 - f)
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
