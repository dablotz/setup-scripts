#!/usr/bin/env bash
# Dry-run test for Mac. No installs are performed — validates config parsing and
# action dispatch by asserting expected lines appear in the script's output.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly FAKE_PROFILE="/tmp/dev_env_test_profile_$$"

cleanup() { rm -f "$FAKE_PROFILE"; }
trap cleanup EXIT

echo "==> Running dry-run test on Mac..."

output=$(bash "$ROOT_DIR/dev_env.sh" \
  --dry-run \
  --config  "$SCRIPT_DIR/dev_env_test.tsv" \
  --profile "$FAKE_PROFILE")

echo "$output"

# ── Assertions ────────────────────────────────────────────────────────────────
pass=0
fail=0

assert_contains() {
  local description="$1" pattern="$2"
  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description"
    echo "        expected pattern: $pattern"
    fail=$((fail + 1))
  fi
}

echo ""
echo "==> Assertions:"
assert_contains "detects mac OS"                    "Detected OS: mac"
assert_contains "skips brew bootstrap"              "\[dry-run\] would bootstrap Homebrew"
assert_contains "would install tree via brew"       "\[dry-run\] would install tree via brew"
assert_contains "would write DEV_ENV_TEST export"   "\[dry-run\] would append.*DEV_ENV_TEST=verified"
assert_contains "would write PATH addition"         "\[dry-run\] would append.*\.local/bin"
assert_contains "would write ll alias"              "\[dry-run\] would append.*alias ll="
assert_contains "dry-run complete message"          "Dry-run complete"

echo ""
if [[ $fail -gt 0 ]]; then
  echo "==> FAILED ($fail failed, $pass passed)"
  exit 1
fi
echo "==> All $pass assertions passed"
