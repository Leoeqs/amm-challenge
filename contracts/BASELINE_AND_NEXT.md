# Baseline and Next Steps

## Where we are

- **Current baseline (this repo):** ~346 edge (99 sims) — single-tier adaptive: 28 bps base, 12 bps bump on large trade (>5%), 18-trade decay, asymmetric.
- **Best result so far:** ~357 edge from the "first version" — we don't have that exact code saved; it may have differed in constants or in number of sims (e.g. 10 sims can show 357, 99 sims 346). We optimize from 346 and aim for 357+.

## Current AdaptiveStrategy.sol (baseline)

- BASE_BPS = 28  
- BUMP_BPS = 12  
- Large threshold = 5% (WAD/20)  
- DECAY_TRADES = 18, DECAY_STEP_BPS = 1  
- Asymmetric bump (full on arb side, half on other)  
- 4 slots only  

## How to optimize from 346 (one change at a time, 99 sims each)

1. **Base fee** — Try 26, 27, 29 (keep rest fixed). Pick best.
2. **Bump** — Try 10, 14 (keep base and rest fixed). Pick best.
3. **Threshold** — Try 4% (WAD/25), 6% (WAD/17). Pick best.
4. **Decay length** — Try 14, 22. Pick best.
5. **Symmetric bump** — Same bump on bid and ask (no half bump). Compare vs asymmetric.
6. **One structural add** (only after tuning above):
   - **Idle reset:** if no trade for 50+ steps, reset to base (needs 1 slot for last timestamp).
   - **Two-tier:** 2% → +5 bps / 6 trades decay, 6% → +12 bps / 14 trades decay.

Always run `amm-match run contracts/src/AdaptiveStrategy.sol --simulations 99` and compare average edge before/after each change.
