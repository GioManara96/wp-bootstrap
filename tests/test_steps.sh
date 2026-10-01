#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for f in utils state naming project-env versions starter; do source "$SCRIPT_DIR/lib/$f.sh"; done
for f in common git starter-copy env-file db-create core wp-install code-pull; do source "$SCRIPT_DIR/lib/steps/$f.sh"; done
source "$SCRIPT_DIR/lib/commands/remote.sh"

# fail-fast stubs: accidental real calls are impossible unless a test redefines them
for _c in ssh scp rsync wp mysql; do
  eval "$_c() { echo \"unexpected \$FUNCNAME \$*\" >&2; exit 99; }"
done

# local-only copy in starter_copy: allow real rsync (no remote host is ever involved)
rsync() { command rsync "$@"; }

fail() { echo "FAIL: $1"; exit 1; }
TMP="$SCRIPT_DIR/tests/tmp/steps_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
DRY_RUN=false; FORCE_STEP=""

# starter fixture
STARTER_DIR="$TMP/starter"
mkdir -p "$STARTER_DIR/wp-content/themes/agency-child" "$STARTER_DIR/wp-content/plugins/foo" "$STARTER_DIR/.git"
printf '@charset "UTF-8";/*!\nTheme Name: {{THEME_NAME}}\nTemplate: astra\n*/\n' > "$STARTER_DIR/wp-content/themes/agency-child/style.css"
printf 'x' > "$STARTER_DIR/.git/HEAD"
touch "$STARTER_DIR/.gitignore" "$STARTER_DIR/.env.example" "$STARTER_DIR/wp-content/plugins/foo/foo.php"

NAME="newsite"; PROJECT_DIR="$TMP/sites/newsite"; LOCAL_URL="http://newsite.stage"

step_starter_copy 2>/dev/null || fail "starter_copy"
css="$PROJECT_DIR/wp-content/themes/newsite/style.css"
grep -q '^Theme Name: newsite$' "$css"                    || fail "theme name not substituted"
[[ ! -e "$PROJECT_DIR/wp-content/themes/agency-child" ]] || fail "child theme not renamed"
[[ ! -e "$PROJECT_DIR/.git" ]]                            || fail "starter .git copied"
[[ -f "$PROJECT_DIR/wp-content/plugins/foo/foo.php" ]]     || fail "plugins not copied"
state_is_done "$PROJECT_DIR" starter_copy                 || fail "starter_copy not marked"
step_starter_copy 2>/dev/null                             || fail "re-run should skip"

# step_begin honors --force-step
state_mark_done "$PROJECT_DIR" demo
step_begin demo "demo" 2>/dev/null && fail "done step not skipped"
FORCE_STEP=demo step_begin demo "demo" 2>/dev/null || fail "--force-step ignored"

# git exclude is idempotent
git init -q "$PROJECT_DIR"
git_exclude_local "$PROJECT_DIR"; git_exclude_local "$PROJECT_DIR"
[[ "$(grep -cxF '.env' "$PROJECT_DIR/.git/info/exclude")" == "1" ]] || fail ".env exclude"
grep -qxF '.bootstrap-state' "$PROJECT_DIR/.git/info/exclude"       || fail ".bootstrap-state exclude"
grep -qxF 'wp-config.php.tmp' "$PROJECT_DIR/.git/info/exclude"      || fail "wp-config.php.tmp exclude"

# env_file (new): LOCAL_URL set, remote keys present but empty
step_env_file new 2>/dev/null || fail "env_file new"
[[ "$(penv_get "$PROJECT_DIR/.env" LOCAL_URL)" == "http://newsite.stage" ]] || fail "LOCAL_URL"
grep -q '^REMOTE_SSH_HOST=$' "$PROJECT_DIR/.env" || fail "remote key placeholder"

# env_file (get): prompts only for remote keys
PROJECT_DIR="$TMP/sites/other"; mkdir -p "$PROJECT_DIR"; LOCAL_URL="http://other.stage"
step_env_file get <<<$'sample-user\n203.0.113.10\nsample_app\nhttps://staging.example.com/' 2>/dev/null || fail "env_file get"
[[ "$(penv_get "$PROJECT_DIR/.env" REMOTE_URL)" == "https://staging.example.com" ]] || fail "REMOTE_URL"

# db_create: db_exists status handling (stubs; mysql_admin must never run)
PROJECT_DIR="$TMP/sites/dbsite"; mkdir -p "$PROJECT_DIR"
DB_NAME=dbsite; DB_USER=dbsite; DB_PASSWORD=x; MYSQL_ADMIN_USER=root
mysql_admin() { fail "mysql_admin called"; }
db_exists() { return 2; }
step_db_create 2>"$TMP/err" && fail "db_create should fail on connection error"
grep -q "Cannot connect to MySQL as root" "$TMP/err" || fail "db_create exit-2 message"
state_is_done "$PROJECT_DIR" db_create && fail "db_create marked done on error"
db_exists() { return 0; }
step_db_create 2>"$TMP/err" && fail "db_create should fail when DB exists"
grep -q "already exists" "$TMP/err" || fail "db_create exists message"
db_exists() { return 1; }
SQLF="$TMP/sql"; : > "$SQLF"
mysql_admin() { printf '%s\n' "$2" >> "$SQLF"; }
mysql() { return 1; }
step_db_create 2>"$TMP/err" && fail "db_create should fail on credential check"
grep -q "different password" "$TMP/err" || fail "credential message"
grep -q 'CREATE DATABASE' "$SQLF" && fail "CREATE DATABASE sent despite failed credential check"
state_is_done "$PROJECT_DIR" db_create && fail "db_create marked done on credential failure"
mysql() { return 0; }
: > "$SQLF"
step_db_create 2>/dev/null || fail "db_create resume should succeed"
grep -q 'CREATE DATABASE' "$SQLF" || fail "CREATE DATABASE not sent on resume"
state_is_done "$PROJECT_DIR" db_create || fail "db_create not marked"
sql="$(cat "$SQLF")"
pos() { local pre="${sql%%"$1"*}"; echo "${#pre}"; }
(( $(pos "CREATE USER") < $(pos "GRANT") && $(pos "GRANT") < $(pos "FLUSH") && $(pos "FLUSH") < $(pos "CREATE DATABASE") )) || fail "SQL order: $sql"
mysql() { echo "unexpected mysql" >&2; exit 99; }

# starter_copy forced re-run: no nesting, style.css mode kept
PROJECT_DIR="$TMP/sites/newsite"
FORCE_STEP=starter_copy step_starter_copy 2>/dev/null || fail "forced starter_copy"
[[ ! -e "$PROJECT_DIR/wp-content/themes/newsite/agency-child" ]] || fail "nested child theme"
[[ ! -e "$PROJECT_DIR/wp-content/themes/agency-child" ]] || fail "child theme left behind"
m="$(stat -f %Lp "$PROJECT_DIR/wp-content/themes/newsite/style.css" 2>/dev/null || stat -c %a "$PROJECT_DIR/wp-content/themes/newsite/style.css")"
[[ "$m" != "600" ]] || fail "style.css mode 600"
FORCE_STEP=""

# starter without a child theme: fails, deletes nothing
PROJECT_DIR="$TMP/sites/nochild"; mkdir -p "$PROJECT_DIR/wp-content/themes/keep"
OLD_STARTER="$STARTER_DIR"; STARTER_DIR="$TMP/starter-nochild"; mkdir -p "$STARTER_DIR/wp-content/themes/plain"
printf '/*\nTheme Name: x\n*/\n' > "$STARTER_DIR/wp-content/themes/plain/style.css"
step_starter_copy 2>/dev/null && fail "starter_copy accepted starter without child theme"
[[ -d "$PROJECT_DIR/wp-content/themes/keep" ]] || fail "theme dir deleted"
STARTER_DIR="$OLD_STARTER"

# git_init: origin mismatch fails
GD="$TMP/sites/gi"; mkdir -p "$GD"; PROJECT_DIR="$GD"; state_init "$GD"
GIT_URL="git@example.com:a/b.git"
step_git_init 2>/dev/null || fail "git_init fresh"
state_clear "$GD" git_init
GIT_URL="git@example.com:other/c.git"
step_git_init 2>/dev/null && fail "git_init accepted different origin"

# env_file (get) imports legacy file first, LOCAL_URL forced
PROJECT_DIR="$TMP/sites/leg"; mkdir -p "$PROJECT_DIR"; LOCAL_URL="http://leg.stage"
cat > "$PROJECT_DIR/db-operation.sh" <<'LEG'
RC_USER=sample-user
RC_APP_NAME=sample_app
W_URL_REMOTE=https://staging.example.com/
RC_SERVERNAME=203.0.113.10
W_URL_LOCAL=http://old.stage
LEG
step_env_file get </dev/null 2>/dev/null || fail "env_file legacy"
[[ "$(penv_get "$PROJECT_DIR/.env" REMOTE_SSH_HOST)" == "203.0.113.10" ]] || fail "legacy not imported"
[[ "$(penv_get "$PROJECT_DIR/.env" LOCAL_URL)" == "http://leg.stage" ]] || fail "LOCAL_URL not forced"

# wp_config renders via .tmp and leaves no temp file
PROJECT_DIR="$TMP/sites/wpc"; mkdir -p "$PROJECT_DIR"; state_init "$PROJECT_DIR"
WPB_ROOT="$SCRIPT_DIR"; DB_NAME=d; DB_USER=u; DB_PASSWORD=p; TABLE_PREFIX=wp_; WP_MEMORY_LIMIT=256M
_fetch_salts() { echo "/* salts */"; }
step_wp_config 2>/dev/null || fail "wp_config"
[[ -f "$PROJECT_DIR/wp-config.php" && ! -e "$PROJECT_DIR/wp-config.php.tmp" ]] || fail "wp-config tmp handling"


# interrupted starter copy stays resumable
source "$SCRIPT_DIR/lib/vhost.sh"; source "$SCRIPT_DIR/lib/project.sh"
NAME="halfsite"; PROJECT_DIR="$TMP/sites/halfsite"; SITES_DIR="$TMP/sites"
rsync() { return 1; }
step_starter_copy >/dev/null 2>&1 && fail "starter_copy should fail with failing rsync"
[[ -f "$PROJECT_DIR/.bootstrap-state" ]] || fail "state file missing after interrupted copy"
preflight_project_dir >/dev/null 2>&1 || fail "interrupted copy not resumable"
rsync() { command rsync "$@"; }

# first push refuses to push tracked secrets
PROJECT_DIR="$TMP/sites/leaky"; mkdir -p "$PROJECT_DIR"; state_init "$PROJECT_DIR"
git init -q -b main "$PROJECT_DIR"; git_exclude_local "$PROJECT_DIR"
grep -qxF 'node_modules/' "$PROJECT_DIR/.git/info/exclude" || fail "node_modules exclude"
printf '<?php\n' > "$PROJECT_DIR/wp-config.php"
out="$(step_first_push 2>&1)" && fail "first_push must refuse tracked wp-config.php"
[[ "$out" == *"Refusing to push"* ]] || fail "no refusal message: $out"

# wp_install: plugin activation retried once (dependency order)
PROJECT_DIR="$TMP/sites/wpi"; mkdir -p "$PROJECT_DIR"; state_init "$PROJECT_DIR"
NAME=wpi; LOCAL_URL="http://wpi.stage"; WP_LOCALE=en_US
ACTF="$TMP/act"; : > "$ACTF"; ACT_FAIL_UNTIL=1
wp() {
  case "$*" in
    "plugin activate --all") echo x >> "$ACTF"; (( $(wc -l < "$ACTF") > ACT_FAIL_UNTIL )); return ;;
    "core is-installed"|"rewrite structure"*|"theme activate wpi") return 0 ;;
    *) echo "unexpected wp $*" >&2; return 99 ;;
  esac
}
step_wp_install 2>"$TMP/err" || fail "wp_install (retry)"
ACT_COUNT="$(wc -l < "$ACTF" | tr -d " ")"; [[ "$ACT_COUNT" == "2" ]] || fail "expected 2 activation passes, got $ACT_COUNT"
grep -q "failed to activate" "$TMP/err" && fail "warning despite successful second pass"
state_is_done "$PROJECT_DIR" wp_install || fail "wp_install not marked (retry)"
state_clear "$PROJECT_DIR" wp_install
: > "$ACTF"; ACT_FAIL_UNTIL=99
step_wp_install 2>"$TMP/err" || fail "wp_install (both fail)"
ACT_COUNT="$(wc -l < "$ACTF" | tr -d " ")"; [[ "$ACT_COUNT" == "2" ]] || fail "expected 2 passes when both fail, got $ACT_COUNT"
grep -q "failed to activate" "$TMP/err" || fail "missing warning when both passes fail"
state_is_done "$PROJECT_DIR" wp_install || fail "wp_install not marked (both fail)"

# git_init without a repo URL: local repo, no origin
PROJECT_DIR="$TMP/sites/adopt-local"; mkdir -p "$PROJECT_DIR"; state_init "$PROJECT_DIR"; GIT_URL=""
step_git_init 2>/dev/null || fail "git_init without url"
[[ -d "$PROJECT_DIR/.git" ]] || fail "git_init without url: no repo"
git -C "$PROJECT_DIR" remote get-url origin >/dev/null 2>&1 && fail "git_init without url added origin"

# gitignore: template copied once, an existing file is kept
WPB_ROOT="$SCRIPT_DIR"
step_gitignore 2>/dev/null || fail "gitignore"
grep -qxF 'wp-config.php' "$PROJECT_DIR/.gitignore" || fail "gitignore template: wp-config.php"
grep -qxF '/wp-content/uploads/' "$PROJECT_DIR/.gitignore" || fail "gitignore template: uploads"
printf 'custom\n' > "$PROJECT_DIR/.gitignore"; state_clear "$PROJECT_DIR" gitignore
step_gitignore 2>/dev/null || fail "gitignore re-run"
[[ "$(cat "$PROJECT_DIR/.gitignore")" == "custom" ]] || fail "existing .gitignore overwritten"

# code_pull: themes, plugins, mu-plugins from the remote wp-content (no uploads)
penv_set "$PROJECT_DIR/.env" REMOTE_SSH_USER sample-user; penv_set "$PROJECT_DIR/.env" REMOTE_SSH_HOST 203.0.113.10
penv_set "$PROJECT_DIR/.env" REMOTE_APP_NAME sample_app
penv_set "$PROJECT_DIR/.env" REMOTE_URL https://staging.example.com; penv_set "$PROJECT_DIR/.env" LOCAL_URL http://adopt-local.stage
RSF="$TMP/rsync-args"
ssh() { return 1; }
rsync() { echo called > "$RSF"; }
: > "$RSF"; step_code_pull 2>"$TMP/err" && fail "code_pull accepted a missing remote wp-content"
grep -q sample_app "$TMP/err" || fail "code_pull missing-remote message: $(cat "$TMP/err")"
[[ -s "$RSF" ]] && fail "code_pull ran rsync without a remote wp-content"
state_is_done "$PROJECT_DIR" code_pull && fail "code_pull marked done after failure"
ssh() { return 0; }
rsync() { printf '%s\n' "$@" > "$RSF"; }
step_code_pull 2>/dev/null || fail "code_pull"
grep -qxF 'sample-user@203.0.113.10:webapps/sample_app/wp-content/' "$RSF" || fail "code_pull source: $(cat "$RSF")"
grep -qxF "$PROJECT_DIR/wp-content/" "$RSF" || fail "code_pull dest"
for d in plugins themes mu-plugins; do grep -qxF "/$d/***" "$RSF" || fail "code_pull misses $d"; done
grep -qxF '*' "$RSF" || fail "code_pull must exclude everything else"
grep -q 'uploads' "$RSF" && fail "code_pull must not copy uploads"
state_is_done "$PROJECT_DIR" code_pull || fail "code_pull not marked"
state_clear "$PROJECT_DIR" code_pull
rsync() { return 23; }
step_code_pull 2>"$TMP/err" || fail "code_pull partial transfer should warn, not fail"
grep -qi partial "$TMP/err" || fail "code_pull partial warning"
state_clear "$PROJECT_DIR" code_pull
rsync() { return 12; }
step_code_pull 2>/dev/null && fail "code_pull failure accepted"
rsync() { command rsync "$@"; }

echo "PASS: test_steps.sh"
