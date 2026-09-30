#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for f in utils versions starter; do source "$SCRIPT_DIR/lib/$f.sh"; done
source "$SCRIPT_DIR/lib/commands/starter-refresh.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/refresh_$$"
trap 'rm -rf "$TMP"' EXIT
DRY_RUN=false; YES=true

STARTER_REPO="$TMP/repo"; S="$STARTER_REPO/starter"
mkdir -p "$S/wp-content/themes/astra" "$S/wp-content/themes/agency-child" "$S/wp-content/plugins/foo"
touch "$S/.gitignore" "$S/.env.example"
printf '/*\nTheme Name: Astra\nVersion: 4.13.9\n*/\n' > "$S/wp-content/themes/astra/style.css"
printf '/*\nTheme Name: {{THEME_NAME}}\nTemplate: astra\n*/\n' > "$S/wp-content/themes/agency-child/style.css"
printf '<?php\n/* Plugin Name: Foo\nVersion: 1.0.0 */\n' > "$S/wp-content/plugins/foo/foo.php"
touch "$S/wp-content/plugins/foo/removed-in-new-version.php"

SITES_DIR="$TMP/sites"
mkdir -p "$SITES_DIR/a/wp-content/plugins/foo" "$SITES_DIR/a/wp-content/themes/astra"
printf '<?php\n/* Plugin Name: Foo\nVersion: 1.1.0 */\n' > "$SITES_DIR/a/wp-content/plugins/foo/foo.php"
printf '/*\nTheme Name: Astra\nVersion: 4.13.10\n*/\n' > "$SITES_DIR/a/wp-content/themes/astra/style.css"

mkdir -p "$SITES_DIR/a/wp-content/plugins/foo/.git" "$SITES_DIR/a/wp-content/plugins/foo/node_modules"
touch "$SITES_DIR/a/wp-content/plugins/foo/.git/HEAD" "$SITES_DIR/a/wp-content/plugins/foo/node_modules/x.js"
cmd_starter_refresh >/dev/null 2>&1 || fail "refresh"
[[ "$(plugin_version "$S/wp-content/plugins/foo")" == "1.1.0" ]]  || fail "plugin not updated"
[[ ! -e "$S/wp-content/plugins/foo/removed-in-new-version.php" ]] || fail "stale file kept"
[[ "$(theme_version "$S/wp-content/themes/astra")" == "4.13.10" ]] || fail "theme not updated"
grep -q 'Template: astra' "$S/wp-content/themes/agency-child/style.css" || fail "child theme touched"

[[ ! -e "$S/wp-content/plugins/foo/.git" && ! -e "$S/wp-content/plugins/foo/node_modules" ]] || fail ".git/node_modules copied"

out="$(cmd_starter_refresh 2>&1)" || fail "second refresh"
[[ "$out" == *"up to date"* ]] || fail "expected up to date: $out"

echo "PASS: test_starter_refresh.sh"
