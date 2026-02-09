// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMStrategyBase} from "./AMMStrategyBase.sol";
import {IAMMStrategy, TradeInfo} from "./IAMMStrategy.sol";

/// @title Baseline: 3-step bump + idle reset + ratio asymmetry. Score 380.15 (99 sims).
contract Strategy is AMMStrategyBase {
    uint256 private constant SLOT_BUMP_UNTIL = 0;
    uint256 private constant SLOT_LAST_TS = 1;
    uint256 private constant IDLE_STEPS = 50;
    uint256 private constant BUMP_STEPS = 3;

    uint256 private constant RATIO_CENTER = 100 * WAD;
    uint256 private constant FEE_BASE_BPS = 26;
    uint256 private constant SLOPE_BPS_PER_PCT = 4;
    uint256 private constant DEVIATION_CAP_PCT = 4;
    uint256 private constant LARGE_PCT = 4;
    uint256 private constant BUMP_MAIN_BPS = 674;
    uint256 private constant BUMP_OTHER_BPS = 300;
    uint256 private constant RATIO_ASYM_BPS = 50;   // always-on: widen arb side by inventory
    uint256 private constant RATIO_ASYM_LO = 99 * WAD;
    uint256 private constant RATIO_ASYM_HI = 101 * WAD;

    function _feeFromRatio(uint256 reserveX, uint256 reserveY) private pure returns (uint256) {
        if (reserveX == 0) return clampFee(30 * BPS);
        uint256 ratio = wdiv(reserveY, reserveX);
        uint256 diff = ratio >= RATIO_CENTER ? (ratio - RATIO_CENTER) : (RATIO_CENTER - ratio);
        uint256 deviationPct = diff / (1e18);
        if (deviationPct > DEVIATION_CAP_PCT) deviationPct = DEVIATION_CAP_PCT;
        uint256 feeBps = FEE_BASE_BPS + SLOPE_BPS_PER_PCT * deviationPct;
        return clampFee(feeBps * BPS);
    }

    /// @dev Apply always-on asymmetry: ratio > 101 -> ask higher; ratio < 99 -> bid higher
    function _applyRatioAsym(uint256 f, uint256 reserveX, uint256 reserveY) private pure returns (uint256 bid, uint256 ask) {
        if (reserveX == 0) return (f, f);
        uint256 ratio = wdiv(reserveY, reserveX);
        if (ratio > RATIO_ASYM_HI) return (f, clampFee(f + RATIO_ASYM_BPS * BPS));
        if (ratio < RATIO_ASYM_LO) return (clampFee(f + RATIO_ASYM_BPS * BPS), f);
        return (f, f);
    }

    function afterInitialize(uint256 initialX, uint256 initialY) external override returns (uint256, uint256) {
        writeSlot(SLOT_BUMP_UNTIL, 0);
        writeSlot(SLOT_LAST_TS, 0);
        uint256 f = _feeFromRatio(initialX, initialY);
        return _applyRatioAsym(f, initialX, initialY);
    }

    function afterSwap(TradeInfo calldata trade) external override returns (uint256, uint256) {
        uint256 lastTs = readSlot(SLOT_LAST_TS);
        bool idle = lastTs == 0 ? (trade.timestamp >= IDLE_STEPS) : (trade.timestamp - lastTs >= IDLE_STEPS);
        writeSlot(SLOT_LAST_TS, trade.timestamp);

        if (idle) {
            writeSlot(SLOT_BUMP_UNTIL, 0);
            uint256 f = _feeFromRatio(trade.reserveX, trade.reserveY);
            return _applyRatioAsym(f, trade.reserveX, trade.reserveY);
        }

        uint256 f = _feeFromRatio(trade.reserveX, trade.reserveY);
        (uint256 baseBid, uint256 baseAsk) = _applyRatioAsym(f, trade.reserveX, trade.reserveY);
        uint256 bumpUntil = readSlot(SLOT_BUMP_UNTIL);
        bool inBumpWindow = trade.timestamp <= bumpUntil;
        bool large = (trade.reserveX != 0 && trade.amountX * 100 >= trade.reserveX * LARGE_PCT)
            || (trade.reserveY != 0 && trade.amountY * 100 >= trade.reserveY * LARGE_PCT);

        if (inBumpWindow || large) {
            if (large) writeSlot(SLOT_BUMP_UNTIL, trade.timestamp + BUMP_STEPS);
            if (trade.isBuy) return (clampFee(baseBid + BUMP_OTHER_BPS * BPS), clampFee(baseAsk + BUMP_MAIN_BPS * BPS));
            return (clampFee(baseBid + BUMP_MAIN_BPS * BPS), clampFee(baseAsk + BUMP_OTHER_BPS * BPS));
        }
        writeSlot(SLOT_BUMP_UNTIL, 0);
        return (baseBid, baseAsk);
    }

    function getName() external pure override returns (string memory) {
        return "Linear_3step_idle50_ratioAsym";
    }
}
