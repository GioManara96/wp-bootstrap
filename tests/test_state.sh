#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/state.sh"

fail() { echo "FAIL: $1"; exit 1; }

TMP_DIR="$SCRIPT_DIR/tests/tmp/state_$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

state_init "$TMP_DIR"
[[ -f "$TMP_DIR/.bootstrap-state" ]] || fail "state_init did not create file"

state_is_done "$TMP_DIR" "01_clone_repo" && fail "should not be done initially"

state_mark_done "$TMP_DIR" "01_clone_repo"
state_is_done "$TMP_DIR" "01_clone_repo" || fail "should be done after mark"

state_mark_done "$TMP_DIR" "02_download_wp"
state_is_done "$TMP_DIR" "02_download_wp" || fail "second mark broken"
state_is_done "$TMP_DIR" "01_clone_repo" || fail "first mark lost"

state_clear "$TMP_DIR" "01_clone_repo"
state_is_done "$TMP_DIR" "01_clone_repo" && fail "should be cleared"
state_is_done "$TMP_DIR" "02_download_wp" || fail "second mark wrongly cleared"

# Re-marking after clear should work
state_mark_done "$TMP_DIR" "01_clone_repo"
state_is_done "$TMP_DIR" "01_clone_repo" || fail "re-mark failed"

# No duplicate entries
state_mark_done "$TMP_DIR" "01_clone_repo"
count=$(grep -c '^01_clone_repo=' "$TMP_DIR/.bootstrap-state")
[[ "$count" == "1" ]] || fail "duplicate entry (got $count)"

echo "PASS: test_state.sh"
