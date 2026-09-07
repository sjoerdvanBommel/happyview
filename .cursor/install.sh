#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for HappyView.
# Prepares system deps, local dev config, the Rust backend, and the web dashboard.
set -euo pipefail

# Run from the repository root regardless of where the script is invoked.
cd "$(dirname "$0")/.."

# --- System dependencies ---------------------------------------------------
# A transitive Rust dependency (openssl-sys) links against the system OpenSSL.
# pkg-config ships in the base image; libssl-dev supplies openssl.pc + headers.
# Guarded so booting from a snapshot that already has it is a no-op.
if ! pkg-config --exists openssl 2>/dev/null; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libssl-dev pkg-config
fi

# --- Local development configuration ---------------------------------------
# SQLite is the zero-setup default database. Generate a strong SESSION_SECRET
# once so the dashboard's cookie auth is enabled; never clobber an existing .env.
if [ ! -f .env ]; then
  secret="$(openssl rand -base64 48)"
  cat > .env <<EOF
DATABASE_URL=sqlite://data/happyview.db?mode=rwc
PUBLIC_URL=http://127.0.0.1:3000
SESSION_SECRET=${secret}
RELAY_URL=https://relay1.us-east.bsky.network
PORT=3000
API_URL=http://127.0.0.1:3000
WEB_HOSTNAME=0.0.0.0
EOF
fi
mkdir -p data

# --- Backend (Rust) --------------------------------------------------------
# rust-toolchain.toml pins the compiler (1.96.1); cargo selects it automatically.
# Building here primes ./target so the `backend` terminal's `cargo run` is fast.
cargo build

# --- Web dashboard (Next.js) ----------------------------------------------
npm --prefix web ci
