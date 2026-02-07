# Strategy Guide

## How to test the strategies

### 1. One-time setup (from repo root)

```bash
# Build the Rust simulation engine (needs Rust + maturin)
cd amm_sim_rs && pip install maturin && maturin develop --release && cd ..

# Install the Python package so `amm-match` is available
pip install -e .
```

### 2. Validate a strategy (checks Solidity rules, compiles, runs one init)

```bash
amm-match validate contracts/src/AdaptiveStrategy.sol
amm-match validate contracts/src/UndercutStrategy.sol
```

### 3. Run simulations and get your edge score

**Single strategy (99 sims, default):**

```bash
amm-match run contracts/src/AdaptiveStrategy.sol
```

**Quick comparison (10 sims each):**

```bash
amm-match run contracts/src/StarterStrategy.sol    --simulations 10
amm-match run contracts/src/UndercutStrategy.sol   --simulations 10
amm-match run contracts/src/AdaptiveStrategy.sol   --simulations 10
```

**Use the test script to run all three and compare:**

```bash
chmod +x scripts/test_strategies.sh
./scripts/test_strategies.sh          # 10 sims each
./scripts/test_strategies.sh 99       # 99 sims each (more stable scores)
```

Output for each run is your strategy’s **average edge** (higher is better). The 30 bps normalizer typically scores around 250–350; your goal is to beat that.

## Strategies included

| File | Idea | Use case |
|------|------|----------|
| **StarterStrategy.sol** | Fixed 50 bps | Template / baseline |
| **VanillaStrategy.sol** | Fixed 30 bps | Normalizer (opponent in sim) |
| **UndercutStrategy.sol** | Fixed 26 bps | Simple undercut; compare vs adaptive |
| **AdaptiveStrategy.sol** | 28 bps base, widen after large trades, asymmetric | Main candidate |

## Adaptive strategy (AdaptiveStrategy.sol)

- **Base fee 28 bps** – Slightly undercuts the 30 bps normalizer to attract more retail.
- **Large-trade trigger** – If a single trade is >5% of reserves (in Y terms), we treat it as a big move; the next step an arb is likely to hit us.
- **Bump** – When triggered, we increase fees (by 12 bps on the “likely hit” side, 6 bps on the other) so the next arb is less profitable.
- **Asymmetry** – We widen the side we expect to get arb’d: after we *sold* X we widen *ask*; after we *bought* X we widen *bid*.
- **Decay** – Over the next 18 trades we step fees back down by 1 bp per trade until we’re back at the 28 bps base.

Constants you can tune in the contract:

- `BASE_BPS` (28) – Base fee; lower = more retail, more arb.
- `BUMP_BPS` (12) – Size of the main bump when we detect a large trade.
- `DECAY_TRADES` (18) – How many trades to hold the bump before starting decay.
- `DECAY_STEP_BPS` (1) – How many bps to subtract per trade during decay.
- Large-trade threshold is fixed at 5% of `reserveY` (`WAD / 20`).

## Tuning tips

1. **Run many sims** – Use `--simulations 99` (or more) to reduce variance and get a stable edge estimate.
2. **Compare** – Run `AdaptiveStrategy.sol` vs `UndercutStrategy.sol` and `StarterStrategy.sol`; compare average edge.
3. **Base fee** – Try 26–30 bps; too low and arb loss can dominate, too high and you lose retail to the normalizer.
4. **Bump size** – Bigger bump reduces arb loss after a large trade but keeps you “stale” longer; smaller bump decays faster.
5. **Decay length** – Longer decay (e.g. 25 trades) keeps fees high longer after a shock; shorter (e.g. 10) returns to competing for retail sooner.

## Submission

For ammchallenge.com, submit a single `.sol` file that defines a contract named **Strategy** inheriting from **AMMStrategyBase**. You can copy `AdaptiveStrategy.sol`, rename the file if you like, but keep the contract name `Strategy`.
