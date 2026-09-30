#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/vhost.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/commands/setup.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/setup_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# legacy import: config_load defaults first (root/empty), legacy values must override them
WPB_CONFIG_FILE="$TMP/nonexistent-config"
printf 'MYSQL_ADMIN_USER=olduser\nMYSQL_ADMIN_PASSWORD="p w"\nDEFAULT_SITES_DIR=$HOME/Old\n' > "$TMP/.env"
config_load
[[ "$MYSQL_ADMIN_USER" == "root" ]] || fail "defaults precondition"
_setup_import_legacy_env "$TMP/.env"
[[ "$MYSQL_ADMIN_USER" == "olduser" ]]  || fail "legacy user"
[[ "$MYSQL_ADMIN_PASSWORD" == "p w" ]]  || fail "legacy quoted password: $MYSQL_ADMIN_PASSWORD"

# cmd_setup imports only when no config exists yet: extract the guard behaviour via source check
grep -qF '[[ -f "$WPB_CONFIG_FILE" ]] || _setup_import_legacy_env' "$SCRIPT_DIR/lib/commands/setup.sh" || fail "first-run-only guard"

# normalize sites dir
[[ "$(_setup_normalize_sites_dir "~/Sites/")" == "$HOME/Sites" ]] || fail "normalize ~ and slash"
[[ "$(_setup_normalize_sites_dir "/a/b//")" == "/a/b" ]] || fail "normalize trailing slashes"
_setup_normalize_sites_dir "rel/path" >/dev/null 2>&1 && fail "relative path accepted"

# --- _setup_wildcard_vhost with stubbed httpd/brew (never touches the real Apache) ---
WPB_ROOT="$SCRIPT_DIR"; DRY_RUN=false; SITES_DIR="$TMP/sites"; LOCAL_TLD="stage"
WPB_CONFIG_FILE="$TMP/config"
VHOST_FILE="$TMP/httpd-vhosts.conf"
BREW_LOG="$TMP/brew.log"; HTTPD_T_RC=0; BREW_RC=0; HTTPD_BIN=httpd
httpd() {
  case "${1:-}" in
    -M) echo " vhost_alias_module (shared)" ;;
    -t) return "$HTTPD_T_RC" ;;
  esac
}
brew() { echo "$*" >> "$BREW_LOG"; return "$BREW_RC"; }

printf '# existing vhosts\n<VirtualHost *:80>\n</VirtualHost>\n' > "$VHOST_FILE"
cp -p "$VHOST_FILE" "$TMP/original.conf"

_setup_wildcard_vhost >/dev/null 2>&1 || fail "wildcard vhost install"
[[ "$(grep -cF "$WPB_VHOST_BEGIN" "$VHOST_FILE")" == "1" ]] || fail "block not appended once"
ls "$VHOST_FILE".bak-wpb-* >/dev/null 2>&1 || fail "backup missing"
[[ "$(cat "$BREW_LOG")" == "services restart httpd" ]] || fail "brew call: $(cat "$BREW_LOG")"

_setup_wildcard_vhost >/dev/null 2>&1 || fail "second call"
[[ "$(grep -cF "$WPB_VHOST_BEGIN" "$VHOST_FILE")" == "1" ]] || fail "block duplicated"
[[ "$(wc -l < "$BREW_LOG" | tr -d ' ')" == "1" ]] || fail "second call restarted httpd"

# httpd -t failure → restore byte-identical, no brew
rm -f "$VHOST_FILE".bak-wpb-* "$BREW_LOG"
cp -p "$TMP/original.conf" "$VHOST_FILE"
HTTPD_T_RC=1
_setup_wildcard_vhost >/dev/null 2>&1 && fail "should fail when httpd -t fails"
cmp -s "$VHOST_FILE" "$TMP/original.conf" || fail "vhosts file not restored"
[[ ! -e "$BREW_LOG" ]] || fail "brew called despite httpd -t failure"

# brew restart failure → error
rm -f "$VHOST_FILE".bak-wpb-* "$BREW_LOG"
cp -p "$TMP/original.conf" "$VHOST_FILE"
HTTPD_T_RC=0; BREW_RC=1
_setup_wildcard_vhost >/dev/null 2>&1 && fail "should fail when brew restart fails"

# block present but SITES_DIR changed → warning; restart hint always
BREW_RC=0
out="$(SITES_DIR="$TMP/other" _setup_wildcard_vhost 2>&1)" || fail "present-block call"
[[ "$out" == *"SITES_DIR changed"* ]] || fail "no SITES_DIR warning: $out"
[[ "$out" == *"brew services restart httpd"* ]] || fail "no restart hint"

echo "PASS: test_setup.sh"
