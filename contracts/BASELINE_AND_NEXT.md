# Baseline and Next Steps

## Baseline (set)

- **Strategy:** `Linear_3step_idle50_ratioAsym` — stateful.
  - **Linear base:** 26 + 4 × min(|ratio−100|%, 4) bps.
  - **Always-on ratio asymmetry:** ratio > 101 → ask +50 bps; ratio < 99 → bid +50 bps.
  - **Idle reset:** If no trade for 50 steps, next fee = linear + ratio asym only (no bump).
  - **3-step bump:** After large trade (≥4% reserves), asymmetric bump (674/300) for **3 steps**; directional by isBuy.
- **Score:** **380.15** (99 sims).
- **File:** `contracts/src/AdaptiveStrategy.sol`.

This is the official baseline. Do not replace it without running 99 sims and comparing to **380.15**.

## Next steps (one change at a time)

- Try RATIO_ASYM 75 (tried, 376.74). Next: two-tier bump; BUMP_STEPS=4; timestamp phases.

**Tried (reverted or worse):**
- Asymmetric rebalancing: **358.15**. Band tuning: **355.18**. Fee levels 25/29/44: **358.57**. Idle reset: **336.63**. Wider band 97–103: **352.75**. Four-band 24 bps: **358.10**. Linear base 25: **359.03**. Linear slope 3: **359.05**.
- **Large-trade threshold 3%** with 674 bps bump: **344.31** (bump too often).
- **Bump 800 bps** (5% threshold): **369.87**. **Symmetric other=400**: **372.87**. **6% threshold asymmetric**: **368.67**. **2-step+idle50**: **375.42**. **3-step**: **375.49**. **Ratio asym 75**: **376.74**.

**Winning change (drastic):** **3-step bump + idle 50 + ratio asymmetry 50 bps** → **380.15** (was 372.93). Previously: **Asymmetric bump** (674 on side arb hits, 300 on other) → **372.93**. One-step bump after large trade** (≥4% of reserves → +674 bps next step) on top of linear-inventory → **372.03** (was 361.40). Research: “dynamical directional fees” and “widen during toxic flow” (arXiv 2406.12417, LVR/fee docs).

Always: `amm-match run contracts/src/AdaptiveStrategy.sol --simulations 99`
