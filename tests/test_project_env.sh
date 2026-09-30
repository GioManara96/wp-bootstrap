#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/naming.sh"
source "$SCRIPT_DIR/lib/project-env.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/penv_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
envf="$TMP/.env"

# set/get, URL normalization, replace without duplicates
penv_set "$envf" REMOTE_SSH_USER alice
penv_set "$envf" REMOTE_URL "https://staging.example.com/"
[[ "$(penv_get "$envf" REMOTE_SSH_USER)" == "alice" ]]                 || fail "get"
[[ "$(penv_get "$envf" REMOTE_URL)" == "https://staging.example.com" ]] || fail "URL not normalized"
penv_set "$envf" REMOTE_SSH_USER bob
[[ "$(grep -c '^REMOTE_SSH_USER=' "$envf")" == "1" ]]  || fail "duplicate key"
[[ "$(penv_get "$envf" REMOTE_SSH_USER)" == "bob" ]]   || fail "replace"
[[ "$(head -1 "$envf")" == "REMOTE_SSH_USER=bob" ]]    || fail "order not preserved"
[[ -z "$(penv_get "$TMP/nope" REMOTE_URL)" ]]           || fail "get on missing file"

# missing keys (empty value counts as missing)
penv_set "$envf" REMOTE_APP_NAME ""
missing="$(penv_missing "$envf" REMOTE_SSH_USER REMOTE_SSH_HOST REMOTE_APP_NAME | tr '\n' ' ')"
[[ "$missing" == "REMOTE_SSH_HOST REMOTE_APP_NAME " ]] || fail "penv_missing: '$missing'"

# ensure prompts only for missing keys, in order
penv_ensure "$envf" REMOTE_SSH_USER REMOTE_SSH_HOST REMOTE_APP_NAME <<<$'203.0.113.10\nsample_app' 2>/dev/null || fail "ensure"
[[ "$(penv_get "$envf" REMOTE_SSH_HOST)" == "203.0.113.10" ]] || fail "ensure host"
[[ "$(penv_get "$envf" REMOTE_APP_NAME)" == "sample_app" ]]   || fail "ensure app"
[[ "$(penv_get "$envf" REMOTE_SSH_USER)" == "bob" ]]          || fail "ensure overwrote existing"
penv_ensure "$TMP/.env2" REMOTE_SSH_HOST <<<"" 2>/dev/null && fail "empty answer accepted"

# load into shell vars
penv_load "$envf"
[[ "$REMOTE_SSH_HOST" == "203.0.113.10" ]] || fail "penv_load"

# legacy sync-operation.sh import
cat > "$TMP/sync-operation.sh" <<'EOF'
#! /bin/bash

#configurazione
RC_USER=sample-user

RC_APP_NAME=sample_app
W_URL_REMOTE=https://staging.example.com/

RC_SERVERNAME=203.0.113.10

W_URL_LOCAL=http://sampleproject.stage


date=$(date '+%Y-%m-%d-%H%M');
EOF
envf3="$TMP/.env3"
penv_import_legacy "$TMP/sync-operation.sh" "$envf3" || fail "import"
[[ "$(penv_get "$envf3" REMOTE_SSH_USER)" == "sample-user" ]]           || fail "import user"
[[ "$(penv_get "$envf3" REMOTE_SSH_HOST)" == "203.0.113.10" ]]          || fail "import host"
[[ "$(penv_get "$envf3" REMOTE_APP_NAME)" == "sample_app" ]]            || fail "import app"
[[ "$(penv_get "$envf3" REMOTE_URL)" == "https://staging.example.com" ]] || fail "import remote url"
[[ "$(penv_get "$envf3" LOCAL_URL)" == "http://sampleproject.stage" ]]   || fail "import local url"
penv_import_legacy "$TMP/none.sh" "$envf3" && fail "import of missing file"

# ---- hardening ----
# no trailing newline
nf="$TMP/nonl"
printf 'LOCAL_URL=http://a.stage' > "$nf"
penv_set "$nf" REMOTE_SSH_USER bob
[[ "$(penv_get "$nf" LOCAL_URL)" == "http://a.stage" ]] || fail "no-newline: LOCAL_URL corrupted"
[[ "$(penv_get "$nf" REMOTE_SSH_USER)" == "bob" ]]      || fail "no-newline: appended key"

# replace keeps permissions
pf="$TMP/perm"
printf 'REMOTE_SSH_USER=a\n' > "$pf"; chmod 600 "$pf"
penv_set "$pf" REMOTE_SSH_USER b
[[ "$(stat -f %Lp "$pf" 2>/dev/null || stat -c %a "$pf")" == "600" ]] || fail "replace changed mode"
[[ ! -e "$pf.tmp" ]] || fail "tmp left behind"

# quotes, CRLF, export
qf="$TMP/quotes"
printf 'REMOTE_URL="https://a.com"\nREMOTE_APP_NAME=https://a.com\r\nexport REMOTE_SSH_USER=bob\n' > "$qf"
[[ "$(penv_get "$qf" REMOTE_URL)" == "https://a.com" ]]      || fail "quoted value"
[[ "$(penv_get "$qf" REMOTE_APP_NAME)" == "https://a.com" ]] || fail "CRLF value"
[[ "$(penv_get "$qf" REMOTE_SSH_USER)" == "bob" ]]           || fail "export prefix"
penv_set "$qf" REMOTE_SSH_USER carl
[[ "$(grep -c 'REMOTE_SSH_USER=' "$qf")" == "1" ]]           || fail "export line duplicated"
[[ "$(penv_get "$qf" REMOTE_SSH_USER)" == "carl" ]]          || fail "export replace"
grep -q '^REMOTE_SSH_USER=carl$' "$qf"                       || fail "export not normalized"

# legacy import: inline comment and variable references
lf="$TMP/legacy2.sh"
printf 'RC_USER="bob" # prod user\nRC_APP_NAME=$APP\nRC_SERVERNAME=1.2.3.4\n' > "$lf"
penv_import_legacy "$lf" "$TMP/.env4" || fail "import2"
[[ "$(penv_get "$TMP/.env4" REMOTE_SSH_USER)" == "bob" ]]     || fail "inline comment"
[[ -z "$(penv_get "$TMP/.env4" REMOTE_APP_NAME)" ]]           || fail "\$var imported"
[[ "$(penv_get "$TMP/.env4" REMOTE_SSH_HOST)" == "1.2.3.4" ]] || fail "plain value lost"

echo "PASS: test_project_env.sh"
