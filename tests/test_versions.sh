#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/versions.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/versions_$$"
mkdir -p "$TMP/plug" "$TMP/theme"
trap 'rm -rf "$TMP"' EXIT

version_gt 4.13.10 4.13.9 || fail "4.13.10 > 4.13.9"
version_gt 6.10 6.9       || fail "6.10 > 6.9"
version_gt 1.0 ""         || fail "1.0 > empty"
version_gt 1.2 1.2        && fail "equal is not greater"
version_gt 1.2 1.3        && fail "1.2 > 1.3"

# helper file before the main file must be ignored (no "Plugin Name:")
printf '<?php\n// Version: 9.9.9 in a comment of a helper\n' > "$TMP/plug/a-helper.php"
printf '<?php\n// Silence is golden.\n' > "$TMP/plug/index.php"
cat > "$TMP/plug/my-plugin.php" <<'EOF'
<?php
/**
 * Plugin Name: My Plugin
 * Description: test
 * Version: 4.3.0
 */
EOF
[[ "$(plugin_version "$TMP/plug")" == "4.3.0" ]] || fail "plugin_version: $(plugin_version "$TMP/plug")"
plugin_version "$TMP/theme" >/dev/null && fail "plugin_version without main file"

printf '/*\nTheme Name: Astra\nVersion: 4.13.10\n*/\n' > "$TMP/theme/style.css"
[[ "$(theme_version "$TMP/theme")" == "4.13.10" ]] || fail "theme_version"
printf '<?php\n/* Plugin Name: Inline\nVersion: 2.0.1 */\n' > "$TMP/theme/inline.php"
[[ "$(plugin_version "$TMP/theme")" == "2.0.1" ]] || fail "trailing */ not stripped: $(plugin_version "$TMP/theme")"

echo "PASS: test_versions.sh"
