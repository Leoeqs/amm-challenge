// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMStrategyBase} from "./AMMStrategyBase.sol";
import {IAMMStrategy, TradeInfo} from "./IAMMStrategy.sol";

/// @title Adaptive Strategy - Compete for retail, widen after large trades
/// @notice Base fee slightly below normalizer (30 bps). After large trades, bump fees
///         to reduce arb size, then decay back. Optionally widens the side likely to get arb'd.
contract Strategy is AMMStrategyBase {
    // Slot layout:
    // slots[0] = current bid fee (WAD)
    // slots[1] = current ask fee (WAD)
    // slots[2] = base fee (WAD) - target when no recent large trade
    // slots[3] = decay counter (0 = use base; >0 = bumped, decrement each trade)

    uint256 private constant SLOT_BID_FEE = 0;
    uint256 private constant SLOT_ASK_FEE = 1;
    uint256 private constant SLOT_BASE_FEE = 2;
    uint256 private constant SLOT_DECAY = 3;

    // === Tuning knobs (run "amm-match run ... --simulations 99" to compare) ===
    /// @notice Base fee: undercut normalizer (30 bps). Lower = more retail + more arb.
    uint256 private constant BASE_BPS = 27;
    /// @notice Fee bump on large trade. Larger = more arb protection, stay stale longer.
    uint256 private constant BUMP_BPS = 10;
    /// @notice Trades to hold bump before decaying back. Shorter = back to base sooner.
    uint256 private constant DECAY_TRADES = 14;
    /// @notice bps to subtract per trade during decay.
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

        // Trade size relative to reserves (Y-denominated). Large = >4% of reserveY
        uint256 tradeRatioY = wdiv(trade.amountY, trade.reserveY);
        uint256 largeThresholdWad = WAD / 25; // 4% (try 20=5%, 33=3% to tune)

        if (tradeRatioY >= largeThresholdWad) {
            // Large trade: bump fees to make next arb less profitable. Asymmetric: widen the side we expect to get hit.
            uint256 bump = bpsToWad(BUMP_BPS);
            if (trade.isBuy) {
                // AMM bought X -> price went down -> arb will buy X from us (we sell X) -> they hit ask
                writeSlot(SLOT_ASK_FEE, clampFee(ask + bump));
                writeSlot(SLOT_BID_FEE, clampFee(bid + bump / 2));
            } else {
                // AMM sold X -> price went up -> arb will sell X to us (we buy X) -> they hit bid
                writeSlot(SLOT_BID_FEE, clampFee(bid + bump));
                writeSlot(SLOT_ASK_FEE, clampFee(ask + bump / 2));
            }
            writeSlot(SLOT_DECAY, DECAY_TRADES);
        } else if (decay > 0) {
            // Decay phase: step toward base each trade
            uint256 decayStep = bpsToWad(DECAY_STEP_BPS);
            uint256 newDecay = decay - 1;
            writeSlot(SLOT_DECAY, newDecay);

            if (newDecay == 0) {
                writeSlot(SLOT_BID_FEE, base);
                writeSlot(SLOT_ASK_FEE, base);
            } else {
                // Move bid and ask toward base by one step (never below base)
                uint256 newBid = bid > base ? (bid <= base + decayStep ? base : bid - decayStep) : bid;
                uint256 newAsk = ask > base ? (ask <= base + decayStep ? base : ask - decayStep) : ask;
                writeSlot(SLOT_BID_FEE, newBid);
                writeSlot(SLOT_ASK_FEE, newAsk);
            }
        }

        return (readSlot(SLOT_BID_FEE), readSlot(SLOT_ASK_FEE));
    }

    function getName() external pure override returns (string memory) {
        return "Adaptive_27bps_opt";
    }
}
