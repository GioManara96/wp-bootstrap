#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/vhost.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/vhost_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/httpd.conf" <<'EOF'
#Include /opt/x/extra/httpd-vhosts-old.conf
Include /opt/homebrew/etc/httpd/extra/httpd-vhosts.conf
EOF
[[ "$(vhost_include_from_conf "$TMP/httpd.conf")" == "/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf" ]] || fail "include detection"
printf 'Listen 80\n' > "$TMP/novhost.conf"
vhost_include_from_conf "$TMP/novhost.conf" >/dev/null && fail "include detection without vhost include"

VHOST_FILE="/custom/vhosts.conf"
[[ "$(vhost_detect_file)" == "/custom/vhosts.conf" ]] || fail "VHOST_FILE override"

block="$TMP/block.conf"
substitute_template "$SCRIPT_DIR/templates/vhost-wildcard.template.conf" "$block" SITES_DIR "/Users/x/Sites" LOCAL_TLD "stage"
grep -qF 'VirtualDocumentRoot "/Users/x/Sites/%-2"' "$block" || fail "VirtualDocumentRoot"
grep -qF '<FilesMatch "^\.(env(\..+)?|bootstrap-state)$">' "$block" || fail "FilesMatch regex"
grep -qF '<DirectoryMatch "/\.git(/|$)">' "$block"       || fail "DirectoryMatch .git"
grep -qF '<Directory "/Users/x/Sites">' "$block"          || fail "quoted Directory"
grep -qF 'Options -Indexes +FollowSymLinks' "$block"      || fail "Indexes/FollowSymLinks"
grep -qF '<Directory "/Users/x/Sites/logs">' "$block"     || fail "logs Directory"
grep -qF 'ErrorLog "/Users/x/Sites/logs/wpb-wildcard-error.log"' "$block" || fail "quoted ErrorLog"
grep -qF 'CustomLog "/Users/x/Sites/logs/wpb-wildcard-access.log"' "$block" || fail "quoted CustomLog"
grep -qF '.htaccess' "$block"                             || fail "htaccess caveat comment"
grep -qF 'ServerAlias *.stage' "$block"                   || fail "ServerAlias"
grep -qF 'Require all denied' "$block"                    || fail ".env protection"
grep -q '{{' "$block"                                     && fail "unrendered placeholder"

printf '# legacy\n<VirtualHost *:80>\n</VirtualHost>\n' > "$TMP/vhosts.conf"
vhost_has_wildcard "$TMP/vhosts.conf" && fail "wildcard detected before insert"
vhost_append_block "$TMP/vhosts.conf" "$block"
vhost_append_block "$TMP/vhosts.conf" "$block"
[[ "$(grep -cF "$WPB_VHOST_BEGIN" "$TMP/vhosts.conf")" == "1" ]] || fail "block inserted twice"
[[ "$(head -1 "$TMP/vhosts.conf")" == "# legacy" ]]               || fail "legacy content moved"
[[ "$(tail -1 "$TMP/vhosts.conf")" == "# <<< wpb: wildcard <<<" ]] || fail "block not at the end"

# has_wildcard needs both markers
printf '%s\n' "$WPB_VHOST_BEGIN" > "$TMP/half.conf"
vhost_has_wildcard "$TMP/half.conf" && fail "begin marker alone detected"

# Include / IncludeOptional, quotes, case
printf 'Include "/a/httpd-vhosts.conf"\n' > "$TMP/q.conf"
[[ "$(vhost_include_from_conf "$TMP/q.conf")" == "/a/httpd-vhosts.conf" ]] || fail "quoted include"
printf 'IncludeOptional /b/extra/httpd-vhosts.conf\n' > "$TMP/o.conf"
[[ "$(vhost_include_from_conf "$TMP/o.conf")" == "/b/extra/httpd-vhosts.conf" ]] || fail "IncludeOptional"
printf 'include /c/httpd-vhosts.conf\n' > "$TMP/l.conf"
[[ "$(vhost_include_from_conf "$TMP/l.conf")" == "/c/httpd-vhosts.conf" ]] || fail "lowercase include"

HTTPD_BIN="/custom/httpd"
[[ "$(httpd_bin)" == "/custom/httpd" ]] || fail "HTTPD_BIN override"
HTTPD_BIN=""; brew() { echo "$TMP/nobrew"; }
httpd_bin >/dev/null 2>&1 && fail "httpd_bin should fail without executable"
mkdir -p "$TMP/nobrew/bin"; printf '#!/bin/sh\n' > "$TMP/nobrew/bin/httpd"; chmod +x "$TMP/nobrew/bin/httpd"
[[ "$(httpd_bin)" == "$TMP/nobrew/bin/httpd" ]] || fail "brew prefix httpd"
unset -f brew

echo "PASS: test_vhost.sh"
