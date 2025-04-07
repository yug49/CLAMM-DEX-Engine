// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * @title CLAMM - Concentrated Liquidity Automated Market Maker
 * @author Yug Agarwal
 * @notice This contract is a simplified version of Uniswap V3's CLAMM
 * @dev It omits Factory, Price Oracle, Flash Swap, NFT, Solidity advanced math libraries, Callbacks
 */
pragma solidity 0.8.19;

import {Tick} from "./lib/Tick.sol";
import {TickMath} from "./lib/TickMath.sol";
import {Position} from "./lib/Position.sol";
import {SafeCast} from "./lib/SafeCast.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SqrtPriceMath} from "./lib/SqrtPriceMath.sol";
import {SwapMath} from "./lib/SwapMath.sol";
import {BitMath} from "./lib/BitMath.sol";
import {TickBitmap} from "./lib/TickBitmap.sol";

contract CLAMM {
    using SafeCast for int256;
    using SafeCast for uint256;
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);

    error CLAMM__AlreadyInitialized();
    error CLAMM__Locked();
    error CLAMM__AmountInvalid();
    error CLAMM__tickLowerGreaterThanOrEqualToUpper();
    error CLAMM__tickLowerLessThanMin();
    error CLAMM__tickUpperGreaterThanMax();
    error CLAMM_InvalidSqrtPriceLimit();

    address public immutable i_token0;
    address public immutable i_token1;
    uint24 public immutable i_fee;
    int24 public immutable i_tickSpacing;
    uint128 public immutable i_maxLiquidityPerTick;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    struct SwapCache {
        //liquidity at the beginning of the swap
        uint128 liquidityStart;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        int256 amountSpecifiedRemaining; // the amount remaining to be swapped in/out of the inpur/output asset
        int256 amountCalculated; // the amount alreadt swapped out/in of the output/input asset
        uint160 sqrtPriceX96; // current sprt(price)
        int24 tick; // the tick associated with the current price
        uint256 feeGrowthGlobalX128; // the global fee growth of the input token
        uint128 liquidity; // the current liquidity in range
    }

    struct StepComputation {
        uint160 sqrtPriceStartX96; // the sqrt price at the begining of the step
        int24 tickNext; // the next tick to swap to from the current tick in the swap direction
        bool initialized; // whether tickNext is initialized or not
        uint160 sqrtPriceNextX96; // sqrt(price) for the next tick (1/0)
        uint256 amountIn; // how much is being swapped in in this step
        uint256 amountOut; // how much is being swapped out
        uint256 feeAmount; // how much fee is being paid in
    }

    Slot0 public slot0;
    uint128 public liquidity;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    mapping(int24 => Tick.Info) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    mapping(bytes32 => Position.Info) public positions;

    event Initialize(uint160 indexed sqrtPriceX96, int24 indexed tick);

    modifier lock() {
        if (slot0.unlocked == false) {
            revert CLAMM__AlreadyInitialized();
        }
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    /**
     *
     * @param _token0 first token in the pair
     * @param _token1 second token in the pair
     * @param _fee swap fees
     * @param _tickSpacing tick spacing
     * @dev tick spacing is the minimum distance between ticks
     */
    constructor(address _token0, address _token1, uint24 _fee, int24 _tickSpacing) {
        i_token0 = _token0;
        i_token1 = _token1;
        i_fee = _fee;
        i_tickSpacing = _tickSpacing;
        i_maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    function initialize(uint160 sqrtPriceX96) external {
        if (slot0.sqrtPriceX96 == 0) {
            revert CLAMM__Locked();
        }

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});

        emit Initialize(sqrtPriceX96, tick);
    }

    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        // mint logic
        if (amount <= 0) revert CLAMM__AmountInvalid();
        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0) {
            IERC20(i_token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(i_token1).transferFrom(msg.sender, address(this), amount1);
        }
    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external lock returns (uint128 amount0, uint128 amount1) {
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20(i_token0).transfer(recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20(i_token1).transfer(recipient, amount1);
        }
    }

    function burn(int24 tickLower, int24 tickUpper, uint128 amount)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) =
                (position.tokensOwed0 + uint128(amount0), position.tokensOwed1 + uint128(amount1));
        }
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external lock returns (int256 amount0, int256 amount1) {
        if (amountSpecified == 0) revert CLAMM__AmountInvalid();

        Slot0 memory slot0Start = slot0;

        if (zeroForOne) {
            if (sqrtPriceLimitX96 >= slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 <= TickMath.MIN_SQRT_RATIO) {
                revert CLAMM_InvalidSqrtPriceLimit();
            }
        } else {
            if (sqrtPriceLimitX96 <= slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 >= TickMath.MAX_SQRT_RATIO) {
                revert CLAMM_InvalidSqrtPriceLimit();
            }
        }

        SwapCache memory cache = SwapCache({liquidityStart: liquidity});

        bool exactInput = amountSpecified > 0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            liquidity: cache.liquidityStart
        });

        // continue swapping as long as there is liquidity and the amount specified is not zero
        //TODO
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputation memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            // TODO next initialized tick

            (step.tickNext, step.initialized) =
                tickBitmap.nextInitializedTickWithinOneWord(state.tick, i_tickSpacing, zeroForOne);

            //Bound tick next
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                i_fee
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated -= step.amountOut.toInt256();
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated += (step.amountIn + step.feeAmount).toInt256();
            }

            // TODO update global fee tracker

            //TODO
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    int128 liquidityNet = ticks.cross(
                        step.tickNext,
                        zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128,
                        zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128
                    );

                    if (zeroForOne) {
                        liquidityNet = -liquidityNet;
                    }

                    state.liquidity = liquidity < 0
                        ? state.liquidity - uint128(-liquidityNet)
                        : state.liquidity + uint128(liquidityNet);
                }
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // if tick at the begining of the trade and afte the trade are not equal then Update the sqrtPticeX96 and tick
        if (state.tick != slot0Start.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        } else {
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        //update liquidity
        if (cache.liquidityStart != state.liquidity) {
            liquidity = state.liquidity;
        }

        //update fee growth
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        if (zeroForOne) {
            if (amount1 < 0) {
                IERC20(i_token1).transfer(recipient, uint256(-amount1));
                IERC20(i_token0).transferFrom(msg.sender, address(this), uint256(amount0));
            }
        } else {
            if (amount0 < 0) {
                IERC20(i_token0).transfer(recipient, uint256(-amount0));
                IERC20(i_token1).transferFrom(msg.sender, address(this), uint256(amount1));
            }
        }
    }

    function _updatePostion(address owner, int24 tickUpper, int24 tickLower, int128 liquidityDelta, int24 tick)
        private
        returns (Position.Info storage position)
    {
        position = positions.get(owner, tickLower, tickUpper);

        // Fees Update
        uint256 _feeGrowthGlobal0X128 = 0;
        uint256 _feeGrowthGlobal1X128 = 0;

        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false, // lower tick
                i_maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true, // upper tick
                i_maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, i_tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, i_tickSpacing);
            }
        }

        // TODO fees
        position.update(liquidityDelta, 0, 0);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        checkTicks(params.tickLower, params.tickUpper);
        Slot0 memory _slot0 = slot0;

        position = _updatePostion(
            params.owner,
            params.tickUpper,
            params.tickLower,
            params.liquidityDelta, // Amount of liquidity to add or remove
            _slot0.tick
        );

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.tickUpper), params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower), _slot0.sqrtPriceX96, params.liquidityDelta
                );

                liquidity = params.liquidityDelta < 0
                    ? liquidity - uint128(-params.liquidityDelta)
                    : liquidity + uint128(params.liquidityDelta);
            } else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        if (tickLower >= tickUpper) {
            revert CLAMM__tickLowerGreaterThanOrEqualToUpper();
        }
        if (tickLower < TickMath.MIN_TICK) {
            revert CLAMM__tickLowerLessThanMin();
        }
        if (tickUpper > TickMath.MAX_TICK) {
            revert CLAMM__tickUpperGreaterThanMax();
        }
    }
}
