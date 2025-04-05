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

contract CLAMM {
    using SafeCast for int256;
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Tick for mapping(int24 => Tick.Info);

    error CLAMM__AlreadyInitialized();
    error CLAMM__Locked();
    error CLAMM__AmountInvalid();
    error CLAMM__tickLowerGreaterThanOrEqualToUpper();
    error CLAMM__tickLowerLessThanMin();
    error CLAMM__tickUpperGreaterThanMax();

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

    Slot0 public slot0;
    mapping(int24 => Tick.Info) public ticks;
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

    function _updatePostion(address owner, int24 tickUpper, int24 tickLower, int128 liquidityDelta, int24 tick)
        private
        returns (Position.Info storage position)
    {
        position = positions.get(owner, tickLower, tickUpper);

        // Fees Update
        uint256 _feeGrowthGlobal0X128 = 0;
        uint256 _feeGrowthGlobal1X128 = 0;

        position.update(liquidityDelta, 0, 0);
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        checkTicks(params.tickLower, params.tickUpper);
        Slot0 memory _slot0 = slot0;

        _updatePostion(
            params.owner,
            params.tickUpper,
            params.tickLower,
            params.liquidityDelta, // Amount of liquidity to add or remove
            _slot0.tick
        );

        return (positions[bytes32(0)], 0, 0);
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
