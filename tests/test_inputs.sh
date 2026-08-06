#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/inputs.sh"

fail() { echo "FAIL: $1"; exit 1; }

# Reset all input vars to ensure clean test
unset NAME GITLAB_URL REMOTE_DOMAIN SSH_USER SSH_HOST RC_APP_NAME
unset DB_NAME DB_USER DB_PASSWORD TABLE_PREFIX LOCAL_DOMAIN
unset FROM_FILE RESUME FORCE FORCE_STEP SKIP_PULL DRY_RUN YES

parse_flags --name foo --gitlab-url git@gitlab.com:o/r.git --remote-domain s.example.com \
            --ssh-user alice --ssh-host 1.2.3.4 --rc-app-name app1 \
            --db-name db1 --db-user u1 --db-password p1 --table-prefix x_ \
            --local-domain foo.stage --resume --force --skip-pull --dry-run --yes \
            --force-step 07

[[ "$NAME" == "foo" ]]                                  || fail "NAME=$NAME"
[[ "$GITLAB_URL" == "git@gitlab.com:o/r.git" ]]         || fail "GITLAB_URL=$GITLAB_URL"
[[ "$REMOTE_DOMAIN" == "s.example.com" ]]               || fail "REMOTE_DOMAIN=$REMOTE_DOMAIN"
[[ "$SSH_USER" == "alice" ]]                            || fail "SSH_USER=$SSH_USER"
[[ "$SSH_HOST" == "1.2.3.4" ]]                          || fail "SSH_HOST=$SSH_HOST"
[[ "$RC_APP_NAME" == "app1" ]]                          || fail "RC_APP_NAME=$RC_APP_NAME"
[[ "$DB_NAME" == "db1" ]]                               || fail "DB_NAME=$DB_NAME"
[[ "$DB_USER" == "u1" ]]                                || fail "DB_USER=$DB_USER"
[[ "$DB_PASSWORD" == "p1" ]]                            || fail "DB_PASSWORD=$DB_PASSWORD"
[[ "$TABLE_PREFIX" == "x_" ]]                           || fail "TABLE_PREFIX=$TABLE_PREFIX"
[[ "$LOCAL_DOMAIN" == "foo.stage" ]]                    || fail "LOCAL_DOMAIN=$LOCAL_DOMAIN"
[[ "$RESUME" == "true" ]]                               || fail "RESUME=$RESUME"
[[ "$FORCE" == "true" ]]                                || fail "FORCE=$FORCE"
[[ "$SKIP_PULL" == "true" ]]                            || fail "SKIP_PULL=$SKIP_PULL"
[[ "$DRY_RUN" == "true" ]]                              || fail "DRY_RUN=$DRY_RUN"
[[ "$YES" == "true" ]]                                  || fail "YES=$YES"
[[ "$FORCE_STEP" == "07" ]]                             || fail "FORCE_STEP=$FORCE_STEP"

# Test .env loader
TMP_ENV="$SCRIPT_DIR/tests/tmp/env_$$"
mkdir -p "$TMP_ENV"
trap 'rm -rf "$TMP_ENV"' EXIT
cat > "$TMP_ENV/.env" <<'EOF'
MYSQL_ADMIN_USER=testuser
MYSQL_ADMIN_PASSWORD=testpass
DEFAULT_VHOST_EMAIL=test@example.com
DEFAULT_SITES_DIR=$HOME/TestSites
DEFAULT_APACHE_VHOST_FILE=/tmp/vhost.conf
DEFAULT_WP_LOCALE=en_US
DEFAULT_WP_MEMORY_LIMIT=512M
EOF

unset MYSQL_ADMIN_USER MYSQL_ADMIN_PASSWORD DEFAULT_VHOST_EMAIL
load_env "$TMP_ENV/.env"
[[ "$MYSQL_ADMIN_USER" == "testuser" ]]                 || fail "env MYSQL_ADMIN_USER"
[[ "$MYSQL_ADMIN_PASSWORD" == "testpass" ]]             || fail "env MYSQL_ADMIN_PASSWORD"
[[ "$DEFAULT_VHOST_EMAIL" == "test@example.com" ]]      || fail "env DEFAULT_VHOST_EMAIL"
[[ "$DEFAULT_WP_MEMORY_LIMIT" == "512M" ]]              || fail "env DEFAULT_WP_MEMORY_LIMIT"

# load_env on missing file should return 1
load_env "$TMP_ENV/nope" 2>/dev/null && fail "load_env should fail on missing file"

# --- save_bootstrap_yml + load_bootstrap_yml ---
# Reset DRY_RUN: parse_flags earlier set it true, but save_bootstrap_yml is a no-op in dry-run.
DRY_RUN=false
TMP_YML_DIR="$SCRIPT_DIR/tests/tmp/yml_$$"
mkdir -p "$TMP_YML_DIR"

NAME=sample-project
GITLAB_URL=git@gitlab.com:org/sample-project.git
REMOTE_DOMAIN=staging.example.com
SSH_USER=deploy
SSH_HOST=203.0.113.10
RC_APP_NAME=sample_app
DB_NAME=sample_db
DB_USER=sample_user
DB_PASSWORD='pa ss"with:special#'
TABLE_PREFIX=wp_
LOCAL_DOMAIN=sampleproject.stage
SKIP_PULL=true

save_bootstrap_yml "$TMP_YML_DIR"
[[ -f "$TMP_YML_DIR/.bootstrap.yml" ]] || fail "yml not saved"

# Clear vars, then load and verify
unset NAME GITLAB_URL REMOTE_DOMAIN SSH_USER SSH_HOST RC_APP_NAME DB_NAME DB_USER DB_PASSWORD TABLE_PREFIX LOCAL_DOMAIN
SKIP_PULL=false

load_bootstrap_yml "$TMP_YML_DIR/.bootstrap.yml"
[[ "$NAME" == "sample-project" ]]                       || fail "yml NAME=$NAME"
[[ "$SSH_HOST" == "203.0.113.10" ]]                     || fail "yml SSH_HOST=$SSH_HOST"
[[ "$DB_PASSWORD" == 'pa ss"with:special#' ]]           || fail "yml DB_PASSWORD=$DB_PASSWORD"
[[ "$SKIP_PULL" == "true" ]]                            || fail "yml SKIP_PULL=$SKIP_PULL"

rm -rf "$TMP_YML_DIR"

echo "PASS: test_inputs.sh"
