# Research: AMM Challenge & How to Improve Edge

## What I found (no direct Twitter strategy leaks)

- **ammchallenge.com** is the official site; it links to GitHub (benedictbrady/amm-challenge) for starter code. The competition is designed by **Benedict Brady** and **Dan Robinson** (Paradigm).
- **Leaderboard** (current): top strategies are **522–524** edge (e.g. v514, Unislop, BubbleSort). Authors are on X/Twitter (@josusanmartin, @danrobinson, @notnotstorm, etc.) but **no public posts** were found that reveal their exact strategy.
- **Academic / industry work** (especially “Optimal Dynamic Fees in Automated Market Makers” and related) gives general principles we can use.

---

## Competition rules (from ammchallenge.com/about)

- Your strategy **does not know** volatility, retail arrival rate, or order size; it must **adapt from observed trades**.
- Scoring is over **1000** randomized simulations (different market conditions). So the goal is **robustness** across environments, not tuning to one.
- **Flow depends on both fee and reserves:** “Higher fees or a less favorable mid price reduce your share of incoming orders.” So when we’re mispriced we get less flow; when we’re near fair we get more.
- **afterSwap** sets fees for the **next** trade only; it does not affect the trade that just happened.

---

## Academic takeaways (optimal dynamic fees)

1. **Two regimes:**  
   - **High fees** to deter arbitrageurs when mispriced.  
   - **Low fees** to attract noise (retail) when conditions are calm.
2. **Good approximation:** Fees that are **linear in inventory** (reserves) and sensitive to external price. We don’t see external price, but we do see **reserves**; so fee as a function of reserve ratio (inventory imbalance) is a reasonable proxy.
3. **Threshold-type behavior:** Adapt to “volatility” or “stress” with a threshold: when above threshold, charge more; when below, compete for flow.

So in our setting: **infer “stress” from trade size and maybe reserve skew**, and **use reserve ratio (inventory)** in the fee rule, not just “bump after large trade.”

---

## Why our “full opt” might have hurt (341)

We added many features at once (phases, two-tier, momentum, ratio band, idle, snap-back). Possible issues:

- **Timestamp phases** (30 → 26 → 28 bps) might not match how the sim’s volatility/flow evolve; 26 bps in the middle could increase arb loss more than retail gain.
- **Reserve-ratio band** (widen when ratio outside 80–125) might widen when we’re actually near fair, or the band might be wrong.
- **Momentum** (extend hold on same-side runs) might keep us wide too long.
- **Too many knobs** made the strategy brittle across the 1000 different sim environments.

So: **simpler + one or two research-backed ideas** may beat “everything at once.”

---

## Documentation read (linear-inventory + bump experiment)

- **Uniswap v4 Dynamic Fees (docs):** Optimal fee depends on volatility and volume of uninformed flow; use cases include asset composition, price momentum. Asymmetric rebalancing → 358.15 (worse).
- **"Optimal Dynamic Fees in AMMs" (arXiv 2506.02869):** Fees **linear in inventory** approximate optimal. Linear 26 + 4×min(deviation%, 4) bps → **361.40**.
- **"Role of fee choice in revenue generation of AMMs" (arXiv 2406.12417):** **Dynamical directional fees** and widening during toxic/informed flow mitigate losses. **One-step bump** after large trade (≥4% of reserves): add 674 bps for next step only → **372.03** (99 sims). Bump sweep: 4–800 bps best near 674; 4% large-trade threshold beat 5% and 3% (3% triggered too often → 344.31).
- **LVR / no-trade region:** Higher fees create larger no-trade region; one-step wide after large trade protects next step from arb.

---

## Concrete next steps (based on research)

### 1. Revert to best baseline (~346)

- **28 bps base, 10 bps bump, 5% threshold, linear decay (18 trades).**  
- No phases, no two-tier, no momentum, no ratio band, no idle (for now). Get back to 346 as the comparison point.

### 2. Add only “idle reset”

- One slot: last trade timestamp.  
- If `timestamp - lastTs > K` (e.g. 50), set fee back to base.  
- This is low-risk and fixes “stuck wide when no flow.”  
- Run 99 (or 1000 if you can) and compare to 346.

### 3. Fee linear in inventory (reserve ratio)

- Academic result: **fees linear in inventory** are a good approximation.  
- We have **reserveY / reserveX** (spot price). Initial ratio = 100.  
- Idea: **base_fee = 28 + k * (ratio - 100)** in bps, clamped to [0, 100] (or similar), with a small k so we’re only slightly more aggressive when ratio is low and slightly wider when ratio is high.  
- Need to do this in WAD and with a small coefficient so we don’t swing wildly.  
- Alternative: **widen when ratio is far from 100** (we tried “outside 80–125”); try a **smoother** rule: e.g. add 1 bps per unit of distance from 100 (capped), instead of a hard band.

### 4. Simpler “two regime” (threshold only)

- Don’t use timestamp phases. Use **one** stress signal: “recent large trade.”  
- **Regime 1 (stress):** after trade > 5% of reserves → higher fee (e.g. 38 bps), hold for **few** trades (e.g. 4–6), then **snap** to base.  
- **Regime 2 (calm):** base 28 bps (or 27).  
- So: **only** “brief wide after large trade + snap-back,” no phases, no momentum, no ratio band. Compare to baseline 346.

### 5. Robustness over 1000 sims

- If you can run **1000** simulations locally (or on the server), optimize for **median** or **mean** edge over 1000, not 99.  
- Avoid strategies that do great in a few environments and badly in others; prefer strategies that are “good enough” everywhere.

---

## Summary

- **No** direct Twitter or public strategy leaks from top competitors.  
- **Yes** to: (1) revert to simple 346 baseline, (2) add idle reset only, (3) try fee linear in reserve ratio (or smoother ratio rule), (4) try “two regime” with brief wide + snap-back only, (5) test over many sims for robustness.  
- **Avoid** piling on many features at once; add one change, measure, then iterate.
