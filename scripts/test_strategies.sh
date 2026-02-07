#!/usr/bin/env bash
# Test all strategy variants and compare edge scores.
# Run from repo root. Requires: Rust engine built, pip install -e .

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STRATEGIES=(
  "contracts/src/StarterStrategy.sol"
  "contracts/src/UndercutStrategy.sol"
  "contracts/src/AdaptiveStrategy.sol"
)

echo "=== Validating strategies ==="
for f in "${STRATEGIES[@]}"; do
  name=$(basename "$f" .sol)
  if amm-match validate "$f" 2>/dev/null; then
    echo "  OK $name"
  else
    echo "  FAIL $name"
    amm-match validate "$f" || true
  fi
done

echo ""
echo "=== Running simulations (10 each for quick comparison) ==="
SIMULATIONS="${1:-10}"
echo "Using --simulations $SIMULATIONS (override with: $0 <number>)"
echo ""

for f in "${STRATEGIES[@]}"; do
  name=$(basename "$f" .sol)
  echo "--- $name ---"
  amm-match run "$f" --simulations "$SIMULATIONS" 2>&1 | tail -5
  echo ""
done

echo "Done. For more stable scores run: $0 99"
