#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/templates_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

out="$TMP/wp-config.php"
substitute_template "$SCRIPT_DIR/templates/wp-config.template.php" "$out" \
  DB_NAME foo_db DB_USER foo_user DB_PASSWORD password DB_HOST localhost \
  TABLE_PREFIX wp_ WP_MEMORY_LIMIT 768M SALTS_BLOCK "define( 'AUTH_KEY', 'x' );"
grep -qF "define( 'DB_NAME', 'foo_db' );" "$out"                  || fail "DB_NAME"
grep -qF "define( 'DB_CHARSET', 'utf8mb4' );" "$out"              || fail "utf8mb4 charset"
grep -qF "define( 'WP_ENVIRONMENT_TYPE', 'local' );" "$out"       || fail "WP_ENVIRONMENT_TYPE"
grep -q "DOCUMENT_ROOT" "$out"                                     && fail "DOCUMENT_ROOT override must be absent"
grep -q '{{' "$out"                                                && fail "unrendered placeholder"
if command -v php >/dev/null; then php -l "$out" >/dev/null || fail "php syntax"; fi

echo "PASS: test_templates.sh"
