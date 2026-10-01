#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for f in utils state naming project-env mysql; do source "$SCRIPT_DIR/lib/$f.sh"; done
source "$SCRIPT_DIR/lib/steps/common.sh"
source "$SCRIPT_DIR/lib/steps/git.sh"
source "$SCRIPT_DIR/lib/steps/plugins-pull.sh"
source "$SCRIPT_DIR/lib/commands/remote.sh"

# fail-fast stubs: accidental real calls are impossible unless a test redefines them
for _c in ssh scp rsync wp mysql; do
  eval "$_c() { echo \"unexpected \$FUNCNAME \$*\" >&2; exit 99; }"
done

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/remote_$$"
mkdir -p "$TMP/legacy"
trap 'rm -rf "$TMP"' EXIT
DRY_RUN=false; YES=false; LOCAL_TLD=stage

# not a WP project
PROJECT_DIR="$TMP/empty"; mkdir -p "$PROJECT_DIR"
project_context </dev/null 2>/dev/null && fail "context accepted a non-WP dir"

# legacy project: .env imported from db-operation.sh, no prompts needed
PROJECT_DIR="$TMP/legacy"
printf '<?php\n' > "$PROJECT_DIR/wp-config.php"
cat > "$PROJECT_DIR/db-operation.sh" <<'EOF'
#! /bin/bash
RC_USER=sample-user
RC_APP_NAME=sample_app
W_URL_REMOTE=https://staging.example.com/
RC_SERVERNAME=203.0.113.10
W_URL_LOCAL=http://sampleproject.stage
EOF
project_context </dev/null 2>/dev/null || fail "context on legacy project"
[[ "$REMOTE_SSH_USER" == "sample-user" ]]            || fail "REMOTE_SSH_USER"
[[ "$REMOTE_URL" == "https://staging.example.com" ]] || fail "REMOTE_URL"
[[ "$LOCAL_URL" == "http://sampleproject.stage" ]]   || fail "LOCAL_URL"
[[ -f "$PROJECT_DIR/.env" ]]                         || fail ".env not written"

# remote command string
[[ "$(_remote_target)" == "sample-user@203.0.113.10" ]] || fail "_remote_target"

# ---- validation: bad host is rejected ----
cp "$PROJECT_DIR/.env" "$TMP/env.good"
penv_set "$PROJECT_DIR/.env" REMOTE_SSH_HOST "-oProxyCommand=x"
project_context </dev/null 2>"$TMP/err" && fail "bad host accepted"
grep -q "REMOTE_SSH_HOST" "$TMP/err" || fail "bad host error names key"
cp "$TMP/env.good" "$PROJECT_DIR/.env"
penv_set "$PROJECT_DIR/.env" REMOTE_URL "https://a.com/x'y"
project_context </dev/null 2>/dev/null && fail "quote in URL accepted"
cp "$TMP/env.good" "$PROJECT_DIR/.env"
project_context </dev/null 2>/dev/null || fail "context after restore"

# ---- db:pull with stubs ----
CALLS="$TMP/calls"; : > "$CALLS"
REMOTE_PREFIX_OUT=$'Deprecated: foo\nbar_\n'
DUMP_BODY='CREATE TABLE `bar_options` (x int);
CREATE TABLE `bar_users` (x int);'
ssh() {
  echo "ssh $*" >> "$CALLS"
  case "$*" in
    *"wp db export -"*)  printf '%s\n' "$DUMP_BODY" ;;
    *"wp db prefix"*)    printf '%s' "$REMOTE_PREFIX_OUT" ;;
    *"wp db import -"*)  cat > "$TMP/pushed.sql" ;;
    *) ;;
  esac
}
wp() { echo "wp $*" >> "$CALLS"; case "$*" in "core is-installed") return 0;; "db prefix") echo "${LOCAL_PREFIX_OUT:-bar_}";; esac; return 0; }
scp() { fail "scp used"; }
cmd_db_pull 2>/dev/null || fail "db:pull"
grep -q 'config set table_prefix bar_' "$CALLS" || fail "prefix from noisy remote"
grep -q 'wp db export tmp/pre-pull-' "$CALLS" || fail "local backup before import"
grep -q 'rm -f' "$CALLS" && fail "remote rm used"
o="$(grep 'db import\|config set\|search-replace\|rewrite flush' "$CALLS" | grep '^wp' | tr '\n' '|')"
[[ "$o" == "wp db import"*"wp config set"*"wp search-replace"*"wp rewrite flush"* ]] || fail "order: $o"
: > "$CALLS"; REMOTE_PREFIX_OUT=$'PHP Warning: x y\n'; DUMP_BODY='CREATE TABLE `zz_options` (x int);
CREATE TABLE `zz_users` (x int);'
cmd_db_pull 2>/dev/null || fail "db:pull fallback"
grep -q 'config set table_prefix zz_' "$CALLS" || fail "fallback prefix"
: > "$CALLS"; REMOTE_PREFIX_OUT=$'other_\n'
cmd_db_pull 2>/dev/null || fail "db:pull mismatch"
grep -q 'table_prefix zz_' "$CALLS" || fail "prefix not in dump must fall back"
: > "$CALLS"; DUMP_BODY=""
ssh() { echo "ssh $*" >> "$CALLS"; case "$*" in *"wp db export -"*) : ;; esac; }
cmd_db_pull 2>/dev/null && fail "empty dump accepted"
grep -q 'db import' "$CALLS" && fail "imported empty dump"

# non-SQL output (e.g. login banner) is rejected before backup/import
: > "$CALLS"; DUMP_BODY="Welcome to the server"
ssh() { echo "ssh $*" >> "$CALLS"; case "$*" in *"wp db export -"*) printf '%s\n' "$DUMP_BODY" ;; esac; }
cmd_db_pull 2>"$TMP/err" && fail "non-SQL dump accepted"
grep -q 'not a SQL dump' "$TMP/err" || fail "non-SQL message"
grep -q '^wp ' "$CALLS" && fail "wp ran before dump validation"

# ---- db:pull URL rewrite: both schemes, JSON-escaped form, real home fixes .env ----
: > "$CALLS"; REMOTE_PREFIX_OUT=$'bar_\n'; DUMP_BODY='CREATE TABLE `bar_options` (x int);'
ssh() { echo "ssh $*" >> "$CALLS"; case "$*" in *"wp db export -"*) printf '%s\n' "$DUMP_BODY" ;; *"wp db prefix"*) printf '%s' "$REMOTE_PREFIX_OUT" ;; esac; }
OPT_HOME="http://staging.example.com/"; OPT_SITEURL="http://staging.example.com"
wp() {
  echo "wp $*" >> "$CALLS"
  case "$*" in
    "core is-installed") return 0 ;;
    "option get home") printf 'Notice: x\n%s\n' "$OPT_HOME" ;;
    "option get siteurl") printf '%s\n' "$OPT_SITEURL" ;;
    "plugin is-active elementor") return 0 ;;
  esac
  return 0
}
cmd_db_pull 2>"$TMP/err" || fail "db:pull url rewrite"
grep -qF 'wp search-replace https://staging.example.com http://sampleproject.stage' "$CALLS" || fail "https form not replaced"
grep -qF 'wp search-replace http://staging.example.com http://sampleproject.stage' "$CALLS"  || fail "http form not replaced"
grep -qF 'wp search-replace https:\/\/staging.example.com http:\/\/sampleproject.stage' "$CALLS" || fail "escaped https form not replaced"
grep -qF 'wp search-replace http:\/\/staging.example.com http:\/\/sampleproject.stage' "$CALLS"  || fail "escaped http form not replaced"
[[ "$(grep -c 'search-replace http://staging.example.com ' "$CALLS")" == "1" ]] || fail "duplicate replacement"
grep -q 'wp elementor flush_css' "$CALLS" || fail "elementor css not flushed"
[[ "$(penv_get "$PROJECT_DIR/.env" REMOTE_URL)" == "http://staging.example.com" ]] || fail "REMOTE_URL not aligned to remote home"
grep -q 'REMOTE_URL' "$TMP/err" || fail "REMOTE_URL change not reported"
# home still remote after search-replace → warning; different host → .env untouched
cp "$TMP/env.good" "$PROJECT_DIR/.env"; : > "$CALLS"
OPT_HOME="https://www.other.example"; OPT_SITEURL="https://www.other.example"
cmd_db_pull 2>"$TMP/err" || fail "db:pull other host"
grep -qF 'wp search-replace https://www.other.example http://sampleproject.stage' "$CALLS" || fail "remote home not replaced"
[[ "$(penv_get "$PROJECT_DIR/.env" REMOTE_URL)" == "https://staging.example.com" ]] || fail "REMOTE_URL changed for another host"
grep -q 'still' "$TMP/err" || fail "missing warning: home not rewritten"
cp "$TMP/env.good" "$PROJECT_DIR/.env"; unset OPT_HOME OPT_SITEURL
project_context </dev/null 2>/dev/null || fail "context after url tests"

# ---- db:push ----
ssh() {
  echo "ssh $*" >> "$CALLS"
  case "$*" in
    *"wp db prefix"*)   printf 'Notice\nbar_\n' ;;
    *"wp db import -"*) cat > "$TMP/pushed.sql" ;;
  esac
}
wp() { echo "wp $*" >> "$CALLS"; case "$*" in "db prefix") echo "${LOCAL_PREFIX_OUT:-bar_}";; "db export"*) mkdir -p "$PROJECT_DIR/tmp"; echo "-- dump" > "$PROJECT_DIR/$3";; esac; return 0; }
: > "$CALLS"; LOCAL_PREFIX_OUT="wp_"
cmd_db_push <<<"y" 2>"$TMP/err" && fail "db:push accepted prefix mismatch"
grep -qi 'mismatch' "$TMP/err" || fail "mismatch message"
grep -q 'db import' "$CALLS" && fail "import attempted on mismatch"
LOCAL_PREFIX_OUT="bar_"; : > "$CALLS"
cmd_db_push <<<"n" 2>/dev/null && fail "db:push ran without confirmation"
grep -q 'db import' "$CALLS" && fail "import without confirmation"
: > "$CALLS"; rm -f "$TMP/pushed.sql"
cmd_db_push <<<"y" 2>/dev/null || fail "db:push confirmed"
grep -q 'wpb-backups/pre-push-' "$CALLS" || fail "remote backup"
grep -qF "wp search-replace 'http:\/\/sampleproject.stage' 'https:\/\/staging.example.com'" "$CALLS" || fail "db:push escaped form"
[[ -s "$TMP/pushed.sql" ]] || fail "dump not streamed via stdin"
b="$(grep -n 'wpb-backups' "$CALLS" | head -1 | cut -d: -f1)"; i="$(grep -n 'db import -' "$CALLS" | head -1 | cut -d: -f1)"
(( b < i )) || fail "backup must precede import"
: > "$CALLS"
ssh() { echo "ssh $*" >> "$CALLS"; case "$*" in *"wp db prefix"*) echo bar_;; *wpb-backups*) return 1;; esac; }
cmd_db_push <<<"y" 2>/dev/null && fail "push continued after backup failure"
grep -q 'db import' "$CALLS" && fail "import after backup failure"

# plugins:pull
DRY_RUN=false; PROJECT_DIR="$TMP/legacy"; : > "$CALLS"
rsync() { echo "rsync $*" >> "$CALLS"; }
cmd_plugins_pull 2>/dev/null || fail "plugins:pull"
grep -q -- '--ignore-existing' "$CALLS" || fail "plugins:pull needs --ignore-existing"
grep -q "sample-user@203.0.113.10:.*/wp-content/plugins/ $PROJECT_DIR/wp-content/plugins/\$" "$CALLS" || fail "plugins:pull src/dest: $(cat "$CALLS")"
grep -q -- '--exclude node_modules' "$CALLS" || fail "plugins:pull excludes"
rsync() { echo "rsync $*" >> "$CALLS"; return 23; }
cmd_plugins_pull 2>/dev/null; [[ $? -eq 23 ]] || fail "rsync exit code not propagated"
# step: 23 is a warning, 1 is fatal
DRY_RUN=false; STATE_FILE="$TMP/legacy/.bootstrap-state"
step_plugins_pull 2>"$TMP/err" || fail "partial transfer should not be fatal"
grep -qi 'partial' "$TMP/err" || fail "partial warning"
rm -f "$STATE_FILE" "$TMP/legacy/.bootstrap-state"
rsync() { return 12; }
step_plugins_pull 2>/dev/null && fail "rsync failure should be fatal"
rsync() { echo "unexpected rsync $*" >&2; exit 99; }
DRY_RUN=true; cmd_ssh 2>/dev/null || fail "ssh dry-run"; DRY_RUN=false

# dry-run makes no changes and needs no project
PROJECT_DIR="$TMP/empty"; DRY_RUN=true
cmd_db_pull 2>/dev/null || fail "dry-run db:pull"

echo "PASS: test_remote.sh"
