// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMStrategyBase} from "./AMMStrategyBase.sol";
import {IAMMStrategy, TradeInfo} from "./IAMMStrategy.sol";

/// @title Adaptive Strategy - Compete for retail, widen after large trades
/// @notice Base fee 28 bps (undercut normalizer 30). After large trades (>5% reserves), bump fees
///         to reduce arb size, then decay back. Asymmetric: widen the side likely to get arb'd.
/// @dev Baseline ~346 (99 sims). First run was ~357; we don't have that exact version. Optimize from here.
contract Strategy is AMMStrategyBase {
    // Slot layout:
    // slots[0] = current bid fee (WAD)
    // slots[1] = current ask fee (WAD)
    // slots[2] = base fee (WAD)
    // slots[3] = decay counter (0 = use base; >0 = bumped, decrement each trade)

    uint256 private constant SLOT_BID_FEE = 0;
    uint256 private constant SLOT_ASK_FEE = 1;
    uint256 private constant SLOT_BASE_FEE = 2;
    uint256 private constant SLOT_DECAY = 3;

    uint256 private constant BASE_BPS = 28;
    uint256 private constant BUMP_BPS = 10;
    uint256 private constant DECAY_TRADES = 18;
    uint256 private constant DECAY_STEP_BPS = 1;

    function afterInitialize(uint256, uint256) external override returns (uint256 bidFee, uint256 askFee) {
        uint256 base = bpsToWad(BASE_BPS);
        writeSlot(SLOT_BASE_FEE, base);
        writeSlot(SLOT_BID_FEE, base);
        writeSlot(SLOT_ASK_FEE, base);
        writeSlot(SLOT_DECAY, 0);
        return (base, base);
    }

    function afterSwap(TradeInfo calldata trade) external override returns (uint256 bidFee, uint256 askFee) {
        uint256 base = readSlot(SLOT_BASE_FEE);
        uint256 bid = readSlot(SLOT_BID_FEE);
        uint256 ask = readSlot(SLOT_ASK_FEE);
        uint256 decay = readSlot(SLOT_DECAY);

        uint256 tradeRatioY = wdiv(trade.amountY, trade.reserveY);
        uint256 largeThresholdWad = WAD / 20; // 5%

        if (tradeRatioY >= largeThresholdWad) {
            uint256 bump = bpsToWad(BUMP_BPS);
            if (trade.isBuy) {
                writeSlot(SLOT_ASK_FEE, clampFee(ask + bump));
                writeSlot(SLOT_BID_FEE, clampFee(bid + bump / 2));
            } else {
                writeSlot(SLOT_BID_FEE, clampFee(bid + bump));
                writeSlot(SLOT_ASK_FEE, clampFee(ask + bump / 2));
            }
            writeSlot(SLOT_DECAY, DECAY_TRADES);
        } else if (decay > 0) {
            uint256 decayStep = bpsToWad(DECAY_STEP_BPS);
            uint256 newDecay = decay - 1;
            writeSlot(SLOT_DECAY, newDecay);

            if (newDecay == 0) {
                writeSlot(SLOT_BID_FEE, base);
                writeSlot(SLOT_ASK_FEE, base);
            } else {
                uint256 newBid = bid > base ? (bid <= base + decayStep ? base : bid - decayStep) : bid;
                uint256 newAsk = ask > base ? (ask <= base + decayStep ? base : ask - decayStep) : ask;
                writeSlot(SLOT_BID_FEE, newBid);
                writeSlot(SLOT_ASK_FEE, newAsk);
            }
        }

        return (readSlot(SLOT_BID_FEE), readSlot(SLOT_ASK_FEE));
    }

    function getName() external pure override returns (string memory) {
        return "Adaptive_28bps_bump10";
    }
}
