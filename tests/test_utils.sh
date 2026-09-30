#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

fail() { echo "FAIL: $1"; exit 1; }

# ---- log functions write to stderr and don't crash ----
log_info "test info"   2>/dev/null || fail "log_info crashed"
log_success "test ok"  2>/dev/null || fail "log_success crashed"
log_warn "test warn"   2>/dev/null || fail "log_warn crashed"
log_error "test error" 2>/dev/null || fail "log_error crashed"

# ---- substitute_template ----
TMP_DIR="$SCRIPT_DIR/tests/tmp"
mkdir -p "$TMP_DIR"
template="$TMP_DIR/tpl.txt"
output="$TMP_DIR/out.txt"

cat > "$template" <<'EOF'
hello {{NAME}}, your domain is {{DOMAIN}} and your prefix is {{PREFIX}}
EOF

substitute_template "$template" "$output" NAME "User" DOMAIN "example.com" PREFIX "abc_"
expected="hello User, your domain is example.com and your prefix is abc_"
got=$(cat "$output")
[[ "$got" == "$expected" ]] || fail "substitute_template: got '$got' expected '$expected'"

# Special characters in value (slash, pipe, ampersand)
echo "url: {{URL}}" > "$template"
substitute_template "$template" "$output" URL "https://staging.example.com/path?q=1&r=2"
got=$(cat "$output")
[[ "$got" == "url: https://staging.example.com/path?q=1&r=2" ]] || fail "substitute_template special chars: got '$got'"

# Multi-line block placeholder
cat > "$template" <<'EOF'
prefix
{{BLOCK}}
suffix
EOF
multiline=$'line1\nline2\nline3'
substitute_template "$template" "$output" BLOCK "$multiline"
got=$(cat "$output")
expected=$'prefix\nline1\nline2\nline3\nsuffix'
[[ "$got" == "$expected" ]] || fail "substitute_template multiline: got '$got'"

# Recursive expansion safety: a value containing {{B}} must NOT be expanded
echo "v={{A}}" > "$template"
substitute_template "$template" "$output" A "literal {{B}}" B "should-not-appear"
got=$(cat "$output")
[[ "$got" == "v=literal {{B}}" ]] || fail "substitute_template should not re-scan inserted value: got '$got'"

# Odd-arg-count guard returns 1
echo "x={{X}}" > "$template"
if substitute_template "$template" "$output" X "ok" ODD_KEY 2>/dev/null; then
  fail "substitute_template should reject odd arg count"
fi

# ---- log_step prints "[<id>] <message>" ----
out="$(log_step core_download "wp core download" 2>&1)"
[[ "$out" == *"[core_download] wp core download"* ]] || fail "log_step format: $out"

# ---- kv_clean_value ----
[[ "$(kv_clean_value '"abc"')" == "abc" ]]        || fail "kv dq"
[[ "$(kv_clean_value "'abc'")" == "abc" ]]        || fail "kv sq"
[[ "$(kv_clean_value $'abc\r')" == "abc" ]]       || fail "kv cr"
[[ "$(kv_clean_value $'"abc"\r')" == "abc" ]]     || fail "kv cr+quotes"
[[ "$(kv_clean_value "\"abc'")" == "\"abc'" ]]    || fail "kv mismatched quotes"
[[ "$(kv_clean_value '"')" == '"' ]]              || fail "kv single quote char"
[[ "$(kv_clean_value 'a"b"')" == 'a"b"' ]]        || fail "kv inner quotes"

echo "PASS: test_utils.sh"
