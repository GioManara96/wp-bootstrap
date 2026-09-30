#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WPB="$SCRIPT_DIR/wpb"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/wpb_$$"
mkdir -p "$TMP/sites"
trap 'rm -rf "$TMP"' EXIT
export WPB_CONFIG_FILE="$TMP/config"

out="$(bash "$WPB" help 2>&1)" || fail "help exit code"
[[ "$out" == *"get <gitlab-url>"* ]] || fail "help text: $out"
bash "$WPB" nope >/dev/null 2>&1 && fail "unknown command accepted"
bash "$WPB" get --bogus x >/dev/null 2>&1 && fail "unknown flag accepted"
bash "$WPB" get git@example.com:g/foo.git >/dev/null 2>&1 && fail "get without config accepted"

: > "$TMP/vhosts.conf"
printf 'SITES_DIR=%s\nMYSQL_ADMIN_USER=root\nVHOST_FILE=%s\n' "$TMP/sites" "$TMP/vhosts.conf" > "$WPB_CONFIG_FILE"
out="$(bash "$WPB" get --dry-run git@example.com:g/foo-bar.git 2>&1)" || fail "dry-run get: $out"
[[ "$out" == *"[plugins_pull]"* && "$out" == *"[first_pull]"* ]] || fail "dry-run steps missing: $out"
[[ "$out" == *"DRY-RUN complete"* ]] || fail "dry-run completion missing: $out"
[[ ! -e "$TMP/sites/foo-bar" ]] || fail "dry-run created the project"
out="$(bash "$WPB" new --dry-run git@example.com:g/foo.git 2>&1)" && fail "new without starter accepted"
[[ "$out" == *"No starter configured"* ]] || fail "new error message: $out"

# flag validation must not hang
run_guard() { # run_guard <args...>: fails the test on hang (kill after 5s), returns wpb's status
  bash "$WPB" "$@" >/dev/null 2>&1 & local pid=$!
  ( sleep 5; kill -9 "$pid" 2>/dev/null ) & local g=$!
  wait "$pid"; local rc=$?
  kill "$g" 2>/dev/null; wait "$g" 2>/dev/null
  return "$rc"
}
run_guard get --dry-run x --name; rc=$?
(( rc != 0 && rc != 137 )) || fail "--name without value: rc=$rc"
run_guard get --dry-run x --force-step; rc=$?
(( rc != 0 && rc != 137 )) || fail "--force-step without value: rc=$rc"
run_guard get --dry-run x --name --dry-run; rc=$?
(( rc != 0 && rc != 137 )) || fail "--name followed by flag: rc=$rc"
out="$(bash "$WPB" get --dry-run x --name 2>&1)"; [[ "$out" == *"--name needs a value"* ]] || fail "--name message: $out"
out="$(bash "$WPB" get a b 2>&1)" && fail "extra positional accepted"
[[ "$out" == *"extra argument"* ]] || fail "extra arg message: $out"
out="$(bash "$WPB" get --dry-run x --force-step bogus 2>&1)" && fail "bad step id accepted"
[[ "$out" == *"plugins_pull"* && "$out" == *"Unknown step id"* ]] || fail "step id message: $out"

# bash 3.2 guard (only where /bin/bash is old)
if [[ -x /bin/bash ]] && /bin/bash -c '(( BASH_VERSINFO[0] < 4 ))'; then
  out="$(/bin/bash "$WPB" help 2>&1)" && fail "old bash accepted"
  [[ "$out" == *"requires Bash 4.0+"* ]] || fail "old bash hint: $out"
fi

echo "PASS: test_wpb.sh"
