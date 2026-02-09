# Baseline and Next Steps

## Baseline (set)

- **Strategy:** Linear-in-inventory + one-step bump after large trade (`Linear_bump4_674`).
  - Base fee: 26 + 4 × min(|ratio−100|%, 4) bps.
  - If last trade ≥ 4% of reserves: add **674 bps** for the next step only (then back to linear).
- **Score:** **372.03** (99 sims).
- **File:** `contracts/src/AdaptiveStrategy.sol`.

This is the official baseline. Do not replace it without running 99 sims and comparing to **372.03**.

## Next steps (one change at a time)

- Try large-trade threshold 6% with same 674 bps bump.
- Try linear slope/base tweaks on top of bump (e.g. 27 base, slope 4).

**Tried (reverted or worse):**
- Asymmetric rebalancing: **358.15**. Band tuning: **355.18**. Fee levels 25/29/44: **358.57**. Idle reset: **336.63**. Wider band 97–103: **352.75**. Four-band 24 bps: **358.10**. Linear base 25: **359.03**. Linear slope 3: **359.05**.
- **Large-trade threshold 3%** with 674 bps bump: **344.31** (bump too often).
- **Bump 800 bps** (5% threshold): **369.87** (worse than 674).

**Winning change:** Added **one-step bump after large trade** (≥4% of reserves → +674 bps next step) on top of linear-inventory → **372.03** (was 361.40). Research: “dynamical directional fees” and “widen during toxic flow” (arXiv 2406.12417, LVR/fee docs).

Always: `amm-match run contracts/src/AdaptiveStrategy.sol --simulations 99`
