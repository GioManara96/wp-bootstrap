#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/naming.sh"
source "$SCRIPT_DIR/lib/vhost.sh"
source "$SCRIPT_DIR/lib/project.sh"

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/project_$$"
mkdir -p "$TMP/sites"
trap 'rm -rf "$TMP"' EXIT

SITES_DIR="$TMP/sites"; LOCAL_TLD=stage; LOCAL_DB_PASSWORD=password
NAME=""; TABLE_PREFIX=""
project_init_vars git@git.example.com:group/Acme-Hotel.git || fail "init vars"
[[ "$NAME" == "acme-hotel" ]]                    || fail "NAME=$NAME"
[[ "$PROJECT_DIR" == "$SITES_DIR/acme-hotel" ]]  || fail "PROJECT_DIR"
[[ "$LOCAL_URL" == "http://acme-hotel.stage" ]]  || fail "LOCAL_URL"
[[ "$DB_NAME" == "acme_hotel_db" ]]              || fail "DB_NAME"
[[ "$DB_USER" == "acme_hotel_user" ]]            || fail "DB_USER"
[[ "$DB_PASSWORD" == "password" ]]                || fail "DB_PASSWORD"
[[ "$TABLE_PREFIX" == "wp_" ]]                    || fail "TABLE_PREFIX"
[[ "$GIT_URL" == "git@git.example.com:group/Acme-Hotel.git" ]] || fail "GIT_URL"

NAME="custom"; project_init_vars git@x:g/whatever.git || fail "--name override"
[[ "$NAME" == "custom" ]] || fail "--name ignored"
NAME=""; project_init_vars git@x:g/foo_bar.git 2>/dev/null && fail "invalid name accepted"

# preflight: absent ok, foreign dir fails, wpb dir resumes
NAME=""; project_init_vars git@x:g/demo.git
preflight_project_dir 2>/dev/null || fail "absent dir rejected"
mkdir -p "$PROJECT_DIR"
preflight_project_dir 2>/dev/null && fail "foreign dir accepted"
touch "$PROJECT_DIR/.bootstrap-state"
preflight_project_dir 2>/dev/null || fail "resume rejected"

# remote must be empty for `new`
git init -q --bare "$TMP/remote.git"
preflight_remote_empty "$TMP/remote.git" 2>/dev/null || fail "empty remote rejected"
git clone -q "$TMP/remote.git" "$TMP/work" 2>/dev/null
git -C "$TMP/work" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$TMP/work" push -q origin HEAD 2>/dev/null
preflight_remote_empty "$TMP/remote.git" 2>/dev/null && fail "non-empty remote accepted"
preflight_remote_empty "$TMP/does-not-exist.git" 2>/dev/null && fail "unreachable remote accepted"

# password quoting hazard
LOCAL_DB_PASSWORD="pa'ss"; NAME=""
project_init_vars git@x:g/pw.git 2>/dev/null && fail "single quote in password accepted"
LOCAL_DB_PASSWORD='pa\ss'; NAME=""
project_init_vars git@x:g/pw.git 2>/dev/null && fail "backslash in password accepted"
LOCAL_DB_PASSWORD=password

# legacy vhost collision
VHOST_FILE="$TMP/vhosts.conf"
cat > "$VHOST_FILE" <<'EOF'
<VirtualHost *:80>
    ServerName oldsite.stage
</VirtualHost>
<VirtualHost *:80>
    ServerName legacy-alias-main.stage
    ServerAlias www.legacy-alias.stage legacy-alias.stage
</VirtualHost>
# >>> wpb: wildcard >>>
<VirtualHost *:80>
    ServerName wpb-wildcard.stage
    ServerAlias *.stage
    ServerAlias newsite.stage
</VirtualHost>
# <<< wpb: wildcard <<<
EOF
NAME=oldsite; preflight_vhost_free 2>/dev/null && fail "legacy ServerName not detected"
NAME=legacy-alias;   preflight_vhost_free 2>/dev/null && fail "legacy ServerAlias not detected"
NAME=newsite;     preflight_vhost_free 2>/dev/null || fail "free name rejected"
NAME=quisi;       preflight_vhost_free 2>/dev/null || fail "partial-word match"
VHOST_FILE="$TMP/missing-vhosts.conf"
NAME=oldsite; preflight_vhost_free 2>/dev/null || fail "missing vhost file should pass"

# rerun hint
NAME="hint"; GIT_URL="git@x.com:a/hint.git"; NO_PULL=false
out="$(project_rerun_hint get 2>&1)"
[[ "$out" == *"wpb get git@x.com:a/hint.git --name hint"* && "$out" != *"--no-pull"* ]] || fail "rerun hint: $out"
NO_PULL=true
out="$(project_rerun_hint get 2>&1)"
[[ "$out" == *"--name hint --no-pull"* ]] || fail "rerun hint no-pull: $out"

echo "PASS: test_project.sh"
