#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/versions.sh"
source "$SCRIPT_DIR/lib/starter.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/starter_$$"
trap 'rm -rf "$TMP"' EXIT

S="$TMP/repo/starter"
mkdir -p "$S/wp-content/themes/astra" "$S/wp-content/themes/agency-child" "$S/wp-content/plugins"
printf '/*\nTheme Name: Astra\nVersion: 4.13.9\n*/\n' > "$S/wp-content/themes/astra/style.css"
printf '@charset "UTF-8";/*!\nTheme Name: {{THEME_NAME}}\nTemplate: astra\n*/\n' > "$S/wp-content/themes/agency-child/style.css"
touch "$S/.gitignore" "$S/.env.example"

STARTER_REPO="$TMP/repo"
[[ "$(starter_dir)" == "$S" ]]                         || fail "starter_dir"
starter_validate "$S" 2>/dev/null                      || fail "valid starter rejected"
[[ "$(starter_child_theme "$S")" == "agency-child" ]] || fail "child theme"
starter_require 2>/dev/null                            || fail "starter_require"
[[ "$STARTER_DIR" == "$S" ]]                           || fail "STARTER_DIR"

rm "$S/.env.example"
starter_validate "$S" 2>/dev/null && fail "missing .env.example accepted"
touch "$S/.env.example"
STARTER_REPO="" starter_require 2>/dev/null && fail "empty STARTER_REPO accepted"

# best candidate across SITES_DIR
SITES_DIR="$TMP/sites"
mkdir -p "$SITES_DIR/a/wp-content/plugins/foo" "$SITES_DIR/b/wp-content/plugins/foo" "$SITES_DIR/b/wp-content/themes/astra"
printf '<?php\n/* Plugin Name: Foo\nVersion: 1.2.0 */\n' > "$SITES_DIR/a/wp-content/plugins/foo/foo.php"
printf '<?php\n/* Plugin Name: Foo\nVersion: 1.3.0 */\n' > "$SITES_DIR/b/wp-content/plugins/foo/foo.php"
printf '/*\nTheme Name: Astra\nVersion: 4.13.10\n*/\n' > "$SITES_DIR/b/wp-content/themes/astra/style.css"
got="$(starter_best_candidate plugins foo 1.1.0)"
[[ "$got" == $'1.3.0\t'"$SITES_DIR/b/wp-content/plugins/foo" ]] || fail "best plugin: $got"
[[ -z "$(starter_best_candidate plugins foo 1.3.0)" ]]            || fail "no newer plugin expected"
got="$(starter_best_candidate themes astra 4.13.9)"
[[ "$got" == $'4.13.10\t'"$SITES_DIR/b/wp-content/themes/astra" ]] || fail "best theme: $got"

# Template: header inside a comment block
mkdir -p "$S/wp-content/themes/other"
S2="$TMP/repo2/starter"; mkdir -p "$S2/wp-content/themes/kid"
touch "$S2/.gitignore" "$S2/.env.example"
printf '/**\n * Theme Name: Kid\n * Template: astra\n */\n' > "$S2/wp-content/themes/kid/style.css"
[[ "$(starter_child_theme "$S2")" == "kid" ]] || fail "' * Template:' header"
rmdir "$S/wp-content/themes/other"

# pre-releases are skipped
mkdir -p "$SITES_DIR/c/wp-content/plugins/bar" "$SITES_DIR/d/wp-content/plugins/bar"
printf '<?php\n/* Plugin Name: Bar\nVersion: 1.4.0-beta1 */\n' > "$SITES_DIR/c/wp-content/plugins/bar/bar.php"
printf '<?php\n/* Plugin Name: Bar\nVersion: 1.3.0 */\n' > "$SITES_DIR/d/wp-content/plugins/bar/bar.php"
got="$(starter_best_candidate plugins bar 1.2.0)"
[[ "$got" == $'1.3.0\t'"$SITES_DIR/d/wp-content/plugins/bar" ]] || fail "pre-release skipped: $got"

echo "PASS: test_starter.sh"
