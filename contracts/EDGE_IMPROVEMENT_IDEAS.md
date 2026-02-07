# All Ways to Improve Edge (Before Committing Changes)

This doc lays out every lever we have and every idea worth considering. No code yet—just the reasoning.

---

## 1. What Edge Is

- **Edge** = sum over all trades of (profit at fair price).
  - **Retail trades:** positive edge (we keep the spread).
  - **Arb trades:** negative edge (we lose to informed flow).
- **Goal:** Increase retail edge and/or reduce arb loss.

We only control **fees** (bid_fee, ask_fee). Fees affect:
1. **Retail routing** – Lower fee → larger γ → more retail flow to us (router splits by marginal price).
2. **Arb size** – Higher fee → arb needs bigger mispricing to profit; when they do trade, our loss per unit can differ.
3. **Arb timing** – Higher fee → we stay mispriced longer (“stale”); then we get arb’d. So there’s a trade-off between “get arb’d less often” vs “get arb’d smaller when we do.”

---

## 2. What We Know (Strategy Information)

We **only** see `TradeInfo` after each trade:

| Field      | What it is |
|-----------|------------|
| `isBuy`   | true = AMM bought X (trader sold X to us) |
| `amountX` | X traded (WAD) |
| `amountY` | Y traded (WAD) |
| `timestamp` | Step index 0 … 9999 |
| `reserveX`, `reserveY` | Our reserves **after** this trade (WAD) |

We do **not** see: fair price, other AMM’s state or fees, whether the trade was arb or retail, or any external data.

So we can only infer from:
- **Trade size** (amountX, amountY) and **reserves** (reserveX, reserveY) → e.g. “big trade relative to pool.”
- **Side** (isBuy) → “our price moved up or down.”
- **timestamp** → “early vs late in the sim” (if we want time-based logic).

---

## 3. Simulation Order (Per Step)

Each step, in order:

1. **Fair price** moves (GBM).
2. **Arbitrageur** hits each AMM if profitable (our fees affect whether and how much they trade).
3. **Retail** orders arrive (Poisson) and are **routed optimally** across the two AMMs given current fees.

So: our fees at the **start** of the step decide arb and routing for **this** step. After a trade, we only get to set fees for the **next** step.

---

## 4. Levers We Have (Ways to Improve Edge)

### A. Base fee level (competing for retail)

- **Mechanism:** Router splits flow by marginal price; lower fee → we get more retail.
- **Trade-off:** Lower fee → more arb when we’re mispriced (arb size and/or frequency).
- **Levers:** Base fee in bps (e.g. 26–30). We can’t see the normalizer’s 30 bps; we just choose a level and see if edge goes up.
- **Ideas:** Try 26, 27, 28, 29. Slightly undercut (27–28) is a reasonable starting point; more aggressive (26) may win more retail but increase arb loss.

### B. When to widen fees (reduce arb loss)

- **Mechanism:** Right after a big move, we’re likely mispriced; next step the arb will hit us. Higher fees make that arb less profitable (smaller size or they wait).
- **What we can use:** “Big” = trade large relative to reserves, e.g. `amountY / reserveY` or `amountX / reserveX` above a threshold.
- **Levers:**
  - **Threshold:** What counts as “large” (e.g. 3%, 4%, 5%, 7% of reserves).
  - **Bump size:** How much we add (e.g. +8, +10, +12 bps).
  - **Which side to widen:** Asymmetric (widen the side we expect the arb to hit) vs symmetric.

### C. When to tighten fees (compete for retail again)

- **Mechanism:** After we’ve been wide for a while, we may be back near fair. Lower fees win more retail.
- **Levers:**
  - **Decay:** After a bump, decay back toward base (current approach).
  - **Decay speed:** How many bps per trade (e.g. 1 or 2) and how many trades until we’re at base (decay length).
  - **No decay:** Just hold the bump for N trades then snap back to base (already possible with current structure).

### D. Asymmetry (bid vs ask)

- **Mechanism:** We can set bid_fee ≠ ask_fee.
  - After we **bought X** (isBuy), our spot went down → arb may **buy X from us** (they hit our **ask**).
  - After we **sold X** (!isBuy), our spot went up → arb may **sell X to us** (they hit our **bid**).
- **Idea:** Widen the side that’s likely to get arb’d (current strategy does this) vs symmetric bump.
- **Other use:** Slightly different base for bid vs ask (e.g. if we infer one side gets more arb over time)—experimental.

### E. Using timestamp (time-of-sim)

- **Mechanism:** We know step index 0 … 9999. Early vs late sim might behave differently (e.g. more volatility early, or reserves drift).
- **Ideas:** Different base or bump/decay by “phase” (e.g. first 2k steps vs rest). Unclear if it helps; needs testing.

### F. Using reserve imbalance

- **Mechanism:** `reserveX`, `reserveY` tell us spot price = reserveY/reserveX. We don’t know fair price, but **large imbalance** (e.g. one reserve much bigger than the other) might mean we’re more mispriced.
- **Idea:** Widen when reserves are very skewed (e.g. ratio above a threshold). Risky: we might widen when we’re actually near fair.

### G. Persistence and state (32 slots)

- We can store:
  - Current bid/ask, base fee, decay counter (already used).
  - Extra state, e.g.:
    - “Last N trade sizes” or a running average of trade size.
    - “Steps since last bump” or “number of large trades in last M steps.”
    - Separate decay counters for bid vs ask if we want finer control.
- **Ideas:**
  - **Momentum:** Several same-side trades in a row → keep fees wider longer or bump again.
  - **Running average trade size:** Bump when recent average size is high.
  - **Time since last large trade:** Decay only after K steps without a large trade (would need to store last “large” timestamp).

---

## 5. Ideas We Haven’t Fully Tried

- **Symmetric bump:** Same bump on bid and ask (simpler; compare vs current asymmetric).
- **Two-tier threshold:** Small bump at 3% trade size, bigger bump at 7%.
- **Faster decay:** 2 bps per trade so we’re back at base sooner and compete for retail more.
- **No decay, snap back:** Hold bumped fee for exactly N trades, then set both to base (cleaner than linear decay).
- **Lower base (26 bps)** with **larger bump (12–14 bps)** when we detect large trade (aggressive retail grab, strong reaction to arb risk).
- **Reserve-ratio rule:** If `reserveY/reserveX` is very high or very low vs initial (10000/100 = 100), widen (experimental).
- **Timestamp phases:** Slightly higher base in first 2000 steps, then lower (or vice versa).

---

## 6. Super-Selective Quoting (Is It Allowed? Yes.)

**Question:** What if we’re “super selective” with quoting—only want flow when we think it’s good?

**Rules:** We **must** return `(bidFee, askFee)` from every `afterSwap` and from `afterInitialize`. We can’t “refuse” to quote. So selectivity = **choosing fee level**, not “on/off.”

- **Wide quote (e.g. 50–100 bps or even 10%):** Router sends almost all retail to the 30 bps normalizer; we get very little flow. Arb also finds us less attractive. So we’re effectively “out of the market.”
- **Tight quote (e.g. 26–28 bps):** We compete for retail and are more exposed to arb.

So **super selective** = use a heuristic for “safe to compete.” When we think we’re safe → return low fees (tight quote). When we don’t → return high fees (wide quote, effectively sit out). That’s fully in accordance with the challenge.

**Trade-off:** If we’re wide too often, we get almost no retail and our total edge is tiny. If we’re tight when we’re about to get arb’d, we take the loss. So the approach only works if:
1. Our “safe” state is **often enough** that we still get meaningful retail volume.
2. Our “safe” state is **well correlated** with “no big arb next step.”

**Possible heuristics for “safe to quote tight”:**
- No large trade in the last K steps (store last large-trade timestamp or a counter).
- Reserves not too skewed vs initial (e.g. ratio reserveY/reserveX within some band around 100).
- We’ve been in decay for a while and are back at base (so we didn’t just get hit by a big move).

**Implementation sketch:** Two modes: “competing” (base fee 27–28 bps) and “sitting out” (e.g. 60 bps or 10%). After each trade, if state says safe → competing; else → sitting out. Use 32 slots for state (e.g. last large-trade step, or “steps since last bump”).

---

## 7. What We Can’t Do (Constraints)

- **No fair price** – We can’t directly “widen when mispriced”; we can only infer from trade size and side.
- **No “was this arb?”** – We can’t treat arb and retail differently in logic; we only see one trade at a time.
- **No other AMM** – We can’t see or react to the normalizer’s fees or flow.
- **No randomness** – Strategy is deterministic given TradeInfo and our state.
- **Storage** – Only 32 slots; we need to keep state small (e.g. a few fee values and counters).
- **Fees** – Must be in [0, 10%] and returned every time; we can’t “skip” updates.

---

## 8. Suggested Order to Explore (Before Committing)

1. **Baseline:** Run current strategy with 99 sims; record average edge.
2. **Base fee:** Change only BASE_BPS (26, 27, 28, 29); run 99 each; pick best.
3. **Bump/decay:** Fix base at that value; vary BUMP_BPS (8, 10, 12) and DECAY_TRADES (10, 14, 20); run 99 each.
4. **Threshold:** Vary large-trade threshold (3%, 4%, 5%, 6%); run 99 each.
5. **Symmetric vs asymmetric:** One version symmetric bump, one asymmetric; compare with same other params.
6. **Snap-back decay:** Replace linear decay with “hold N trades, then set fee = base”; compare.
7. **Optional:** Try one reserve-ratio or timestamp-phase idea; run 99 and see if edge improves.

Use this list to decide what to implement and test next, then commit only after 99-sim comparisons.
