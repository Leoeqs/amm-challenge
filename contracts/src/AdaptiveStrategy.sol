// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMStrategyBase} from "./AMMStrategyBase.sol";
import {IAMMStrategy, TradeInfo} from "./IAMMStrategy.sol";

/// @title Baseline: linear-in-inventory + one-step bump after large trade
/// @notice fee = 26 + 4*min(|ratio-100|%, 4) bps; if trade >= 4% of reserves add +674 bps for next step. Score 372.03 (99 sims).
contract Strategy is AMMStrategyBase {
    uint256 private constant RATIO_CENTER = 100 * WAD;
    uint256 private constant FEE_BASE_BPS = 26;
    uint256 private constant SLOPE_BPS_PER_PCT = 4;
    uint256 private constant DEVIATION_CAP_PCT = 4;
    uint256 private constant LARGE_PCT = 4;   // 4% of reserve = large
    uint256 private constant BUMP_BPS = 674;

    function _feeFromRatio(uint256 reserveX, uint256 reserveY) private pure returns (uint256) {
        if (reserveX == 0) return clampFee(30 * BPS);
        uint256 ratio = wdiv(reserveY, reserveX);
        uint256 diff = ratio >= RATIO_CENTER ? (ratio - RATIO_CENTER) : (RATIO_CENTER - ratio);
        uint256 deviationPct = diff / (1e18);
        if (deviationPct > DEVIATION_CAP_PCT) deviationPct = DEVIATION_CAP_PCT;
        uint256 feeBps = FEE_BASE_BPS + SLOPE_BPS_PER_PCT * deviationPct;
        return clampFee(feeBps * BPS);
    }

    function afterInitialize(uint256 initialX, uint256 initialY) external pure override returns (uint256, uint256) {
        uint256 f = _feeFromRatio(initialX, initialY);
        return (f, f);
    }

    function afterSwap(TradeInfo calldata trade) external pure override returns (uint256, uint256) {
        uint256 f = _feeFromRatio(trade.reserveX, trade.reserveY);
        bool large = (trade.reserveX != 0 && trade.amountX * 100 >= trade.reserveX * LARGE_PCT)
            || (trade.reserveY != 0 && trade.amountY * 100 >= trade.reserveY * LARGE_PCT);
        if (large) f = clampFee(f + BUMP_BPS * BPS);
        return (f, f);
    }

    function getName() external pure override returns (string memory) {
        return "Linear_bump4_674";
    }
}
