#!/usr/bin/env bash
# Quality gate for a Rust Lambda: format, lint, test, then build the ARM64 release artifact.
# Run from the crate or workspace root. Exits non-zero on the first failure.
# Usage: preflight.sh [extra args for cargo lambda build, e.g. --output-format zip]
set -euo pipefail

step() { printf '\n==> %s\n' "$*"; }

command -v cargo-lambda >/dev/null 2>&1 || {
  echo "cargo-lambda is not installed: https://www.cargo-lambda.info/guide/installation.html" >&2
  exit 1
}

step "cargo fmt --check"
cargo fmt --all --check

step "cargo clippy --all-targets -- -D warnings"
cargo clippy --all-targets -- -D warnings

step "cargo test"
cargo test

step "cargo lambda build --release --arm64 $*"
cargo lambda build --release --arm64 "$@"

step "Artifacts"
ls -lh target/lambda/*/bootstrap* 2>/dev/null || echo "no artifacts found under target/lambda"

printf '\nAll checks passed. Ready to deploy once the user confirms the target account and region.\n'
