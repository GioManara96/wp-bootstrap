#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/mysql.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/mysql_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/dump.sql" <<'EOF'
CREATE TABLE `abc_cmplz_options` (id int);
CREATE TABLE `abc_actionscheduler_group_options` (id int);
CREATE TABLE `abc_options` (option_id bigint);
CREATE TABLE `abc_posts` (ID bigint);
CREATE TABLE `abc_users` (ID bigint);
EOF
[[ "$(sql_table_prefix "$TMP/dump.sql")" == "abc_" ]] || fail "prefix: $(sql_table_prefix "$TMP/dump.sql")"

printf 'CREATE TABLE `wp_posts` (ID bigint);\n' > "$TMP/none.sql"
[[ -z "$(sql_table_prefix "$TMP/none.sql")" ]] || fail "prefix without options table"

# ---- table prefix hardening ----
cat > "$TMP/ine.sql" <<'EOF'
CREATE TABLE IF NOT EXISTS `wp_options` (id int);
CREATE TABLE IF NOT EXISTS `wp_users` (id int);
EOF
[[ "$(sql_table_prefix "$TMP/ine.sql")" == "wp_" ]] || fail "IF NOT EXISTS: '$(sql_table_prefix "$TMP/ine.sql")'"
cat > "$TMP/nousers.sql" <<'EOF'
CREATE TABLE `w_options` (id int);
CREATE TABLE `wp_options` (id int);
CREATE TABLE `wp_users` (id int);
EOF
[[ "$(sql_table_prefix "$TMP/nousers.sql")" == "wp_" ]] || fail "users check: '$(sql_table_prefix "$TMP/nousers.sql")'"

# ---- db_exists with a stub mysql ----
MYSQL_ADMIN_USER=u; MYSQL_ADMIN_PASSWORD='s3cr3t-pw'
STUB_MODE=ok
mysql() {
  [[ "$*" != *"$MYSQL_ADMIN_PASSWORD"* ]] || { echo "LEAK" >&2; return 99; }
  [[ "$STUB_MODE" == ok ]] || return 1
  echo "abc_db"
}
db_exists abc_db; rc=$?;  [[ $rc -eq 0 ]] || fail "db_exists present rc=$rc"
db_exists other;  rc=$?;  [[ $rc -eq 1 ]] || fail "db_exists absent rc=$rc"
STUB_MODE=down
db_exists abc_db; rc=$?;  [[ $rc -eq 2 ]] || fail "db_exists conn failure rc=$rc"
unset -f mysql
unset MYSQL_ADMIN_USER MYSQL_ADMIN_PASSWORD

echo "PASS: test_mysql.sh"
