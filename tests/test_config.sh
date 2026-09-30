#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$SCRIPT_DIR/tests/tmp/config_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
export WPB_CONFIG_FILE="$TMP/wpb/config"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"

fail() { echo "FAIL: $1"; exit 1; }
reset_vars() { unset SITES_DIR MYSQL_ADMIN_USER MYSQL_ADMIN_PASSWORD LOCAL_DB_PASSWORD STARTER_REPO WP_LOCALE WP_MEMORY_LIMIT LOCAL_TLD VHOST_FILE; }

# Defaults without a file
reset_vars
config_load
[[ "$SITES_DIR" == "$HOME/Sites" ]]  || fail "default SITES_DIR=$SITES_DIR"
[[ "$MYSQL_ADMIN_USER" == "root" ]]  || fail "default MYSQL_ADMIN_USER"
[[ "$LOCAL_DB_PASSWORD" == "password" ]] || fail "default LOCAL_DB_PASSWORD"
[[ "$WP_LOCALE" == "it_IT" ]]        || fail "default WP_LOCALE"
[[ "$LOCAL_TLD" == "stage" ]]        || fail "default LOCAL_TLD"

# Save + reload, mode 600
SITES_DIR=/tmp/s; MYSQL_ADMIN_USER=admin; MYSQL_ADMIN_PASSWORD='p@ss w=rd'; STARTER_REPO=/tmp/st
config_save
perm="$(stat -f %Lp "$WPB_CONFIG_FILE" 2>/dev/null || stat -c %a "$WPB_CONFIG_FILE")"
[[ "$perm" == "600" ]] || fail "config perms=$perm"
reset_vars
config_load
[[ "$SITES_DIR" == "/tmp/s" ]]              || fail "reload SITES_DIR"
[[ "$MYSQL_ADMIN_PASSWORD" == 'p@ss w=rd' ]] || fail "reload password"
[[ "$STARTER_REPO" == "/tmp/st" ]]          || fail "reload STARTER_REPO"

# The file is parsed, never sourced; unknown keys are ignored
printf 'EVIL=$(touch %s/pwned)\nFOO=bar\n' "$TMP" >> "$WPB_CONFIG_FILE"
unset FOO
config_load
[[ ! -e "$TMP/pwned" ]] || fail "config file was executed"
[[ -z "${FOO:-}" ]]     || fail "unknown key loaded"

# config_require
config_require 2>/dev/null || fail "config_require with file"
WPB_CONFIG_FILE="$TMP/missing" config_require 2>/dev/null && fail "config_require without file"

# ---- hardening ----
printf 'MYSQL_ADMIN_PASSWORD="q"\r\n' > "$WPB_CONFIG_FILE"
reset_vars; config_load
[[ "$MYSQL_ADMIN_PASSWORD" == "q" ]] || fail "quoted/CRLF config value: '$MYSQL_ADMIN_PASSWORD'"

printf 'x' > "$WPB_CONFIG_FILE"; chmod 644 "$WPB_CONFIG_FILE"
config_save
perm="$(stat -f %Lp "$WPB_CONFIG_FILE" 2>/dev/null || stat -c %a "$WPB_CONFIG_FILE")"
[[ "$perm" == "600" ]] || fail "config_save on existing 644 file: $perm"

# quotes-wrapped value survives save+load
reset_vars; MYSQL_ADMIN_PASSWORD='"pw"'; config_defaults; config_save
reset_vars; config_load
[[ "$MYSQL_ADMIN_PASSWORD" == '"pw"' ]] || fail "quoted password roundtrip: '$MYSQL_ADMIN_PASSWORD'"

echo "PASS: test_config.sh"
