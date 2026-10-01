#!/usr/bin/env bash
# lib/project.sh — per-run project variables, preflight checks, final summary.
# Requires lib/utils.sh, lib/naming.sh and lib/vhost.sh.

# project_init_vars <git-url> — sets NAME (unless given via --name), PROJECT_DIR,
# LOCAL_URL, DB_NAME, DB_USER, DB_PASSWORD, TABLE_PREFIX, GIT_URL.
# An empty <git-url> (wpb adopt without a repo) needs --name.
project_init_vars() {
  GIT_URL="$1"
  if [[ -z "$GIT_URL" && -z "${NAME:-}" ]]; then
    log_error "No repo URL: pass --name <name>."
    return 1
  fi
  [[ -n "${NAME:-}" ]] || NAME="$(name_from_git_url "$GIT_URL")"
  NAME="$(tr '[:upper:]' '[:lower:]' <<<"$NAME")"
  if ! valid_project_name "$NAME"; then
    log_error "Invalid project name '$NAME' (lowercase letters, digits, dashes). Pass --name <name>."
    return 1
  fi
  if [[ "${LOCAL_DB_PASSWORD:-}" == *"'"* || "${LOCAL_DB_PASSWORD:-}" == *'\'* ]]; then
    log_error "LOCAL_DB_PASSWORD must not contain ' or \\ (it is written into wp-config.php). Run 'wpb setup'."
    return 1
  fi
  PROJECT_DIR="$SITES_DIR/$NAME"
  LOCAL_URL="$(local_url_for "$NAME")"
  DB_NAME="$(db_name_for "$NAME")"
  DB_USER="$(db_user_for "$NAME")"
  DB_PASSWORD="$LOCAL_DB_PASSWORD"
  [[ -n "${TABLE_PREFIX:-}" ]] || TABLE_PREFIX="wp_"
}

# preflight_project_dir — the dir must be absent, or a wpb dir being resumed
preflight_project_dir() {
  if [[ -f "$PROJECT_DIR/.bootstrap-state" ]]; then
    log_info "Resuming $NAME (found $PROJECT_DIR/.bootstrap-state)"
    return 0
  fi
  if [[ -e "$PROJECT_DIR" ]]; then
    log_error "$PROJECT_DIR already exists and was not created by wpb. Use --name or remove it."
    return 1
  fi
}

# preflight_remote_empty <git-url> — `wpb new` and `wpb adopt` only push into an empty repo
preflight_remote_empty() {
  local out
  if ! out="$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git ls-remote "$1" 2>&1)"; then
    log_error "Cannot reach $1: $out"
    return 1
  fi
  if [[ -n "$out" ]]; then
    log_error "$1 is not empty. 'wpb new' and 'wpb adopt' need an empty repo; for a project already on git use 'wpb get'."
    return 1
  fi
}

# preflight_vhost_free — "$NAME.$LOCAL_TLD" must not be declared by a legacy vhost
# (outside the wpb wildcard block): legacy blocks win over the wildcard.
preflight_vhost_free() {
  local file host re
  file="$(vhost_detect_file)" || return 0
  [[ -f "$file" ]] || return 0
  host="$NAME.$LOCAL_TLD"
  re="${host//./\\.}"
  if sed '/# >>> wpb: wildcard >>>/,/# <<< wpb: wildcard <<</d' "$file" \
      | grep -qiE "^[[:space:]]*Server(Name|Alias)[[:space:]]+(.*[[:space:]])?${re}([[:space:]]|\$)"; then
    log_error "$host is already served by a legacy vhost in $file. Use --name."
    return 1
  fi
}

# project_rerun_hint <get|new|adopt> — printed when a step failed
project_rerun_hint() {
  local extra=""
  [[ "${NO_PULL:-false}" == "true" ]] && extra=" --no-pull"
  log_error "Fix the cause, then re-run: wpb $1${GIT_URL:+ $GIT_URL} --name $NAME$extra"
}

# print_summary <new|get|adopt>
print_summary() {
  local admin=""
  [[ "$1" == "new" ]] && admin="   (admin / admin)"
  cat >&2 <<EOF

============================================================
wpb — $NAME ready
============================================================
  Site:    $LOCAL_URL
  Admin:   $LOCAL_URL/wp-admin$admin
  Folder:  $PROJECT_DIR
  DB:      $DB_NAME / $DB_USER
EOF
  [[ "$1" == "adopt" ]] || printf '  npm:     tail -f %s/tmp/npm-install.log\n' "$PROJECT_DIR" >&2
  if [[ "$1" == "new" ]]; then
    cat >&2 <<EOF

Next: create the RunCloud app + GitLab deploy webhook.
      'wpb db:pull' / 'wpb db:push' will ask for the remote data once.
EOF
  fi
  if [[ "$1" == "adopt" ]]; then
    cat >&2 <<EOF

Admin:  same users and passwords as the remote site.
Next:   wpb assets:pull (uploads)${GIT_URL:+ · RunCloud: link the app to $GIT_URL (deploy webhook)}
EOF
    [[ -n "$GIT_URL" ]] || printf '        No repo: local git only. To publish later: git remote add origin <url> && git push -u origin main\n' >&2
  fi
  printf '============================================================\n' >&2
}
