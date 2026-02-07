# Closing the Gap: 342 → 500+

Leaderboard top 10: **518–522** avg edge. Our current run: **~342**. Gap ≈ **175–180 points** — too large for tuning alone. We need structural changes.

---

## Why the gap is probably structural

- **Tuning** (base/bump/decay/threshold) might gain 20–50 points if we find a sweet spot.
- **~180 points** suggests leaders are doing something different: better state, better reaction to “when we’re mispriced,” or better use of the same levers (e.g. when to be wide vs tight).

So: improve structure first, then tune.

---

## High-impact directions (no super-selective)

### 1. **Two-tier reaction (size-based)**

- **Now:** One threshold (4% of reserves) → one bump (10 bps).
- **Change:** Two thresholds → two bump sizes.
  - “Medium” trade (e.g. 2–4% of reserves): small bump (+5 bps) so we react to smaller moves.
  - “Large” trade (e.g. >6%): bigger bump (+12 bps).
- **Why it might help:** We protect a bit on medium moves without staying max-wide too long; we protect more on big moves. More granular = better trade-off between retail and arb.

### 2. **Reset when we’ve been idle (timestamp)**

- **Now:** We only decay when we get a *trade*. If we’re bumped and then get no trades for many steps (no retail, no arb), we stay bumped until the next trade.
- **Change:** Store `lastTradeTimestamp` in a slot. If `trade.timestamp - lastTradeTimestamp > K` (e.g. 50 or 100), treat as “idle” and **reset to base** (and clear decay). So after a big trade we bump; if the next 50 steps have no flow, next time we’re hit we’re already at base and can compete for retail again.
- **Why it might help:** Avoids staying wide for hundreds of steps when there’s no flow; when flow resumes we’re competitive.

### 3. **Snap-back instead of linear decay**

- **Now:** Decay 1 bp per trade until we reach base (many trades).
- **Change:** Hold the bumped fee for exactly N trades (e.g. 5 or 10), then **snap** both sides back to base. Simpler state; we’re “back in” after a fixed number of trades.
- **Why it might help:** Cleaner behavior; easier to tune “how long we stay wide” (just N). Might match server dynamics better.

### 4. **Reserve-ratio band (widen when very skewed)**

- **Idea:** Initial ratio is 10000/100 = 100. If `reserveY/reserveX` goes very far from 100 (e.g. < 80 or > 125), we might be mispriced → widen (e.g. add 5–10 bps) until ratio comes back toward 100.
- **Why it might help:** Extra signal for “we’re likely mispriced” without needing to be super selective; we only widen when reserves are extreme.
- **Risk:** Might widen when we’re actually near fair; test with 99 sims.

### 5. **Momentum (same-side runs)**

- **Idea:** Store “last trade side” and a counter. If the last 2–3 trades were all the same side (all isBuy or all !isBuy), we’re likely trending → extend bump or widen the side that’s getting hit.
- **Why it might help:** Captures “we’re being arb’d repeatedly” and reacts by staying wider a bit longer.
- **Cost:** Uses 1–2 more slots (last side, run length).

### 6. **Symmetric vs asymmetric bump (A/B test)**

- **Now:** Asymmetric (full bump on “arb side,” half on the other).
- **Test:** Symmetric (same bump on bid and ask). Run 99 sims each; compare. Leaders might be symmetric or a different asymmetry.

### 7. **Time-of-sim (timestamp phases)**

- **Idea:** Use `trade.timestamp`: e.g. first 2000 steps use base 28 bps, after that 26 bps (or the reverse). One constant per phase.
- **Why it might help:** Early sim might be more volatile; late sim reserves might be drifted. Different fee by phase could capture that.
- **Risk:** Might be noise; quick to test.

---

## Suggested order of implementation

1. **Timestamp idle-reset** (slot for last timestamp; if delta > K, reset to base) — low risk, fixes “stuck wide when no flow.”
2. **Two-tier bump** (e.g. 2% → +5 bps, 6% → +12 bps) — more granular reaction.
3. **Snap-back** (hold bump for N trades, then set fee = base) — replace linear decay; compare with 99 sims.
4. **Reserve-ratio rule** (widen when ratio outside 80–125 or similar) — optional experiment.
5. **Momentum** (same-side run → extend or widen) — if we have slots left.
6. **Symmetric bump** and **timestamp phases** — quick A/B tests.

After each change, run **99 sims** and compare to current 342. Goal: get to 400+ first, then iterate toward 500+.
