# Deep Optimization: How to Reach 500+

We're at ~346. Leaderboard is 518–522. The gap (~170 points) is too large for parameter tweaks alone. This doc thinks through what could explain it and what radical changes to try.

---

## 1. Why the gap is structural

- **Tuning** (base, bump, threshold, decay) might move us 20–40 points.
- **170 points** implies top strategies differ in *structure*: what they react to, how long they stay wide, and how much time they spend at a competitive fee.

So we need different *rules*, not just different constants.

---

## 2. What actually happens each step (and what we can infer)

**Per step, in order:**
1. Fair price `p` moves (GBM).
2. **Arb** runs on each AMM; if profitable they trade. Our fee and reserves set *whether* they trade and *how much*.
3. **Retail** orders arrive (Poisson); router splits between us and normalizer to equalize *marginal* price. Our fee (and reserves) set our share.

**We only see:** one callback per trade, with `(isBuy, amountX, amountY, timestamp, reserveX, reserveY)`. We do **not** see: fair price, “was this arb or retail?”, or the other AMM.

**Critical:** We get a callback only when *we* have a trade. So:
- **Same timestamp, multiple callbacks** = we had several trades in one step (e.g. one arb + some retail).
- **timestamp - lastTimestamp > 1** = at least one step passed with *no* trade for us. Our fees were unchanged during that gap; when the next trade comes we might already be back near fair, but we’re still wide if we were bumped. **Idle reset** fixes this: if “no trade for K steps,” reset to base.

So the first big structural add is: **idle reset** (one slot for last timestamp). Without it we stay wide during quiet periods and lose retail when flow resumes.

---

## 3. How the router and arb really work

**Router:** Split so marginal prices match. With `γ_i = 1 - f_i`, `A_i = sqrt(x_i * γ_i * y_i)`, share depends on **ratio** of the A’s. So:
- A small fee edge (e.g. 28 vs 30 bps) can shift a **disproportionate** share of volume our way.
- If we’re wide (e.g. 40 bps) we get much less retail; when we’re at base we want to be *at or below* 30 bps.

**Arb:** They trade when our spot ≠ fair. Higher fee → they need a bigger mispricing to profit, and when they do trade they get less size (we keep more). So:
- Right after a big move we’re mispriced → we *want* high fees for 1–2 steps.
- After that, we’re often back near fair → we want to be at base (or below) to capture retail.

**Implication:** We should be **wide for a short window** after a large trade, then **snap back to base** (or below). Linear decay over 18 trades means we’re “half-wide” for a long time; that hurts average fee and retail share. **Snap-back** (hold bump for N trades, then fee = base) keeps us at base more of the time → more retail, same arb protection when it matters.

---

## 4. Time at base vs average fee

Normalizer is fixed 30 bps. If we’re at 28 bps 80% of the time and 40 bps 20% of the time, our *effective* competition for retail is better than if we’re at 28 half and 40 half. So:
- **Maximize fraction of time (or of trades) at base.**
- After a large trade: wide for **as few trades as possible** that still protect the next 1–2 arb hits, then **snap** to base.

That suggests: **short bump window + snap-back**, not long linear decay.

---

## 5. What we’re still not using

**A. Timestamp (step index 0..9999)**  
We have it every trade. We can:
- **Idle reset:** `timestamp - lastTimestamp > K` → reset to base (we already argued for this).
- **Phases:** Different base by time. E.g. first 1–2k steps more conservative (30 bps), middle aggressive (26 bps), end 28 bps. No extra slots; just `if (timestamp < 2000) return 30e14; else if (timestamp < 8000) return 26e14; else return 28e14;` (with bump logic on top). Tests whether early/late sim behaves differently.

**B. Reserve ratio (spot = reserveY/reserveX)**  
Initial ratio = 100. If we’re at 60 or 150 we’re likely skewed. We could add a **small** widen when ratio is outside [80, 125] (or similar). Risky: we might widen when we’re fine; worth one experiment.

**C. Momentum (same-side runs)**  
If the last 2–3 trades were all `isBuy` (or all sell), we’re probably being arbed repeatedly on that side. Reaction: extend the bump (more trades) or add a bit more on that side. Uses 1–2 slots (e.g. last side, run length).

**D. “Safe” vs “recent large”**  
We could define: “safe” = no large trade for the last 20+ trades (store last-large timestamp). In “safe” we use **lower base** (26 bps); when we’re in “recent large” we use 28 or 30. So we’re more aggressive when we think we’re not mispriced.

---

## 6. Radical changes that could get us toward 500+

**R1. Idle reset (must-have)**  
- One slot: last trade timestamp.  
- If `timestamp > lastTimestamp + K` (e.g. 40–60), set fees to base, decay = 0.  
- Prevents staying wide during long quiet spells; when flow resumes we’re competitive.

**R2. Snap-back instead of linear decay**  
- After large trade: set fee to base + bump (e.g. 28+12 = 40 bps), set counter = N (e.g. 5 or 8).  
- Next N trades: return that fee (no decay).  
- On the (N+1)th trade: set fee = base, counter = 0.  
- We’re at base more of the time; arb is still protected for the first few trades after the move.

**R3. “Brief wide” + aggressive base**  
- Base = 26 bps (aggressive).  
- On large trade: go to 38–40 bps for **3–5 trades** then snap to 26.  
- We’re only wide briefly; most of the time we’re at 26 and grab retail.

**R4. Timestamp phases**  
- Base as function of step: e.g. 0–1500: 30 bps, 1500–8500: 26 bps, 8500–10000: 28 bps.  
- Bump logic unchanged on top.  
- No extra slots; pure function of `trade.timestamp`.

**R5. Momentum**  
- Store last trade side and “run length.” If run length ≥ 2 and same side, we’re being arbed on that side → extend bump (e.g. reset decay counter to 5) or add 2–3 bps on that side.  
- Uses 1–2 slots.

**R6. Two-tier (granular reaction)**  
- Medium trade (e.g. 2% of reserves): small bump (+4 bps), short snap (3 trades).  
- Large trade (6%): bigger bump (+12 bps), longer snap (6 trades).  
- Reacts to medium moves without going full-wide for long.

**R7. Reserve-ratio band**  
- If `reserveY/reserveX` < 80 or > 125, add e.g. 5 bps (we might be mispriced).  
- Experimental; one A/B test.

---

## 7. Suggested order of implementation

1. **Idle reset only** (on current best: 28 base, 10 bump, 5%, 18 decay). Add one slot, reset to base when `timestamp - lastTimestamp > 50`. Run 99 sims. If edge goes up, keep it.
2. **Snap-back only** (same baseline). Replace linear decay with “hold bump for 6 trades, then snap to base.” Compare 99 sims.
3. **Idle + snap-back together** with current base/bump/threshold.
4. **Add timestamp phases** (e.g. conservative start, aggressive middle). Compare.
5. **Try base 26** with “brief wide” (bump 12, snap after 5 trades). Compare.
6. **Momentum** (extend bump on same-side run). Compare.
7. **Two-tier** (medium 2% / small bump / short snap, large 6% / big bump / longer snap). Compare.
8. **Reserve-ratio** as one experiment.

Always one structural change at a time (or one clear combo like idle+snap), 99 sims, compare to previous best.

---

## 8. How top strategies might think

- **Maximize time at a competitive fee** (at or below 30 bps) so the router sends us retail.
- **Widen only when necessary** (right after a large trade) and for **as short a time as possible** (snap-back, not long decay).
- **Never stay wide when we haven’t had a trade in a while** (idle reset).
- **Use all available signal:** timestamp (idle, phases), reserve ratio (skew), same-side runs (momentum).
- **Be willing to run a lower base** (26 bps) and accept slightly more arb in exchange for much more retail, as long as the “wide” window is short and sharp.

That combination could plausibly explain a 150+ point gain over a strategy that uses only “bump on large trade + linear decay” with no idle reset and no snap-back.
