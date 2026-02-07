# Setup Guide

## Prerequisites

1. **Python 3.10+** (3.11 or 3.12 recommended; 3.13 may work but has fewer prebuilt wheels)
2. **Rust** – required to build `pyrevm` (Python bindings to the Rust EVM). Without it you get `metadata-generation-failed` when running `pip install -e .`.

### Install Rust

On macOS/Linux, install the Rust toolchain (includes `cargo`):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Choose the default install. Then **restart your terminal** (or run `source "$HOME/.cargo/env"`) so `cargo` is on your PATH.

Verify:

```bash
cargo --version
```

Then install the project:

```bash
cd /Users/leomargolis/Documents/amm-challenge
pip install -e .
```

---

## Full install (including Rust engine for simulations)

From the repo root:

```bash
# 1. Install Rust (see above) if not already installed

# 2. Install Python package (this will build pyrevm from source)
pip install -e .

# 3. Build the Rust simulation engine (maturin builds the amm_sim_rs extension)
cd amm_sim_rs && pip install maturin && maturin develop --release && cd ..

# 4. Confirm
amm-match validate contracts/src/AdaptiveStrategy.sol
amm-match run contracts/src/AdaptiveStrategy.sol --simulations 10
```

---

## If `pip install -e .` still fails on pyrevm

- **Rust not found:** Run `rustup` install above and ensure `cargo` is in your PATH in the same terminal where you run `pip`.
- **Python 3.13:** If the build fails, try a virtualenv with Python 3.11 or 3.12:
  ```bash
  python3.12 -m venv .venv
  source .venv/bin/activate
  pip install -e .
  ```
- **Other build errors:** Check that you have a C compiler (Xcode Command Line Tools on macOS: `xcode-select --install`).
