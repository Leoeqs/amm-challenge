# Optimizing the Adaptive Strategy

Your current run gave **Edge: 354.73** (10 sims). Use **99 simulations** for stable comparison when tuning.

## Quick compare (99 sims)

```bash
# From repo root
amm-match run contracts/src/AdaptiveStrategy.sol --simulations 99
```

Then change constants in `AdaptiveStrategy.sol`, run again, and compare the average Edge.

---

## What each knob does

| Constant | Current | Effect | Try |
|----------|---------|--------|-----|
| **BASE_BPS** | 27 | Base fee vs 30 bps normalizer. Lower = more retail, more arb. | 26, 27, 28 |
| **BUMP_BPS** | 10 | How much we raise fees after a large trade. Bigger = more arb protection, stay “stale” longer. | 8, 10, 12 |
| **largeThresholdWad** | `WAD/25` (4%) | When to treat a trade as “large.” Lower = bump more often. | `WAD/33` (3%), `WAD/20` (5%) |
| **DECAY_TRADES** | 14 | How many trades before we’re fully back to base fee. Shorter = compete for retail again sooner. | 10, 14, 20 |
| **DECAY_STEP_BPS** | 1 | How many bps we drop per trade during decay. | 1, 2 |

- **Goal:** More retail edge, less arb loss.  
- **Trade-off:** Lower base fee → more flow but more arb; higher bump → less arb damage per event but slower return to base.

---

## Changes in the current “optimized” set

- **BASE_BPS 28 → 27** – Slightly more undercut to capture more retail.
- **BUMP_BPS 12 → 10** – Smaller bump so we don’t stay wide too long.
- **Large threshold 5% → 4%** – React to slightly smaller big trades.
- **DECAY_TRADES 18 → 14** – Return to base fee a bit faster.

Run **99 sims** before and after to see if Edge improves; then tweak one knob at a time and re-run 99 to see the effect.
