#!/usr/bin/env bash
# lib/mysql.sh — admin mysql client wrapper and SQL dump helpers.

# mysql_admin <mysql args...> — runs mysql as MYSQL_ADMIN_USER (password via env, not argv)
mysql_admin() {
  MYSQL_PWD="${MYSQL_ADMIN_PASSWORD:-}" mysql -u "${MYSQL_ADMIN_USER:-root}" -h localhost "$@"
}

# db_exists <name> — 0 exists, 1 not found, 2 connection/query failure
db_exists() {
  local out
  out="$(mysql_admin -N -e "SHOW DATABASES LIKE '$1'")" || return 2
  grep -qxF "$1" <<<"$out"
}

# sql_table_prefix <dump.sql> — shortest prefix P such that both "<P>options" and "<P>users"
# tables exist (the core WordPress tables)
sql_table_prefix() {
  local names p best=""
  names="$(grep -oE 'CREATE TABLE (IF NOT EXISTS )?`[A-Za-z0-9_]*(options|users)`' "$1" \
             | sed -E 's/^CREATE TABLE (IF NOT EXISTS )?`//; s/`$//')"
  while IFS= read -r p; do
    [[ "$p" == *options ]] || continue
    p="${p%options}"
    grep -qxF "${p}users" <<<"$names" || continue
    if [[ -z "$best" || ${#p} -lt ${#best} ]]; then best="$p"; fi
  done <<<"$names"
  printf '%s' "$best"
}
