#!/usr/bin/env bash
# lib/commands/remote.sh — db:pull, db:push, assets:pull, assets:push, ssh.
# Same behavior as the legacy sync-operation.sh, reading the project .env.

# project_context — PROJECT_DIR (default: cwd) must be a WP project. Imports a legacy
# sync-operation.sh/db-operation.sh when .env is missing, asks for missing remote keys,
# loads REMOTE_* and LOCAL_URL.
project_context() {
  PROJECT_DIR="${PROJECT_DIR:-$PWD}"
  if [[ ! -f "$PROJECT_DIR/wp-config.php" ]]; then
    log_error "Not a WordPress project: $PROJECT_DIR (no wp-config.php). Run from the project folder."
    return 1
  fi
  local envf="$PROJECT_DIR/.env" legacy home
  if [[ ! -f "$envf" ]]; then
    for legacy in sync-operation.sh db-operation.sh; do
      if [[ -f "$PROJECT_DIR/$legacy" ]]; then
        log_info "Importing remote settings from $legacy into .env"
        penv_import_legacy "$PROJECT_DIR/$legacy" "$envf"
        break
      fi
    done
  fi
  if [[ -z "$(penv_get "$envf" LOCAL_URL)" ]]; then
    home="$(in_project wp option get home 2>/dev/null || true)"
    penv_set "$envf" LOCAL_URL "${home:-$(local_url_for "$(basename "$PROJECT_DIR")")}"
  fi
  penv_ensure "$envf" "${PENV_REMOTE_KEYS[@]}" || return 1
  penv_load "$envf"
  _validate_remote_config "$envf" || return 1
  git_exclude_local "$PROJECT_DIR"
}

# _validate_remote_config <envfile> — reject values that could inject ssh options or shell syntax
_validate_remote_config() {
  local envf="$1" k v
  for k in REMOTE_SSH_USER REMOTE_APP_NAME; do
    v="${!k}"
    if [[ ! "$v" =~ ^[A-Za-z0-9._-]+$ || "$v" == -* ]]; then
      log_error "Invalid $k='$v' in $envf"; return 1
    fi
  done
  v="$REMOTE_SSH_HOST"
  if [[ ! "$v" =~ ^[A-Za-z0-9.:-]+$ || "$v" == -* ]]; then
    log_error "Invalid REMOTE_SSH_HOST='$v' in $envf"; return 1
  fi
  for k in REMOTE_URL LOCAL_URL; do
    v="${!k}"
    if [[ ! "$v" =~ ^https?:// || "$v" == *"'"* || "$v" =~ [[:space:]] ]]; then
      log_error "Invalid $k='$v' in $envf (must be http(s)://… with no quotes or spaces)"; return 1
    fi
  done
}

_remote_target() { printf '%s@%s' "$REMOTE_SSH_USER" "$REMOTE_SSH_HOST"; }
_remote_app() { printf 'webapps/%s' "$REMOTE_APP_NAME"; }

# _remote <shell command> — run inside the remote app folder
_remote() { ssh "$(_remote_target)" "cd $(_remote_app) && $1"; }

# _last_line_trim — reads stdin, prints the last line trimmed (wp may print PHP notices first)
_last_line_trim() { tail -n1 | tr -d '[:space:]'; }

cmd_db_pull() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: db:pull (remote export streamed → import → search-replace)"; return 0; fi
  project_context || return 1
  local stamp dump prefix
  stamp="$(date '+%Y-%m-%d-%H%M')"
  dump="export-remote-$stamp.sql"
  mkdir -p "$PROJECT_DIR/tmp" || return 1
  log_info "db:pull $REMOTE_URL → $LOCAL_URL"
  if ! ssh "$(_remote_target)" "cd $(_remote_app) && wp db export - --quiet" > "$PROJECT_DIR/tmp/$dump"; then
    log_error "db:pull: remote export failed"; return 1
  fi
  if [[ ! -s "$PROJECT_DIR/tmp/$dump" ]]; then
    log_error "db:pull: remote export is empty"; return 1
  fi
  if ! grep -q '^CREATE TABLE' "$PROJECT_DIR/tmp/$dump"; then
    log_error "db:pull: remote output is not a SQL dump (check the remote shell prints nothing on login)"
    return 1
  fi
  # Back up the local DB when WP is installed (it may be empty on a first pull).
  if in_project wp core is-installed >/dev/null 2>&1; then
    in_project wp db export "tmp/pre-pull-$stamp.sql" --quiet || { log_error "db:pull: local backup failed"; return 1; }
    log_info "db:pull: local DB backed up to tmp/pre-pull-$stamp.sql"
  fi
  # The remote install is authoritative; the dump is only a fallback.
  prefix="$(_remote "wp db prefix" 2>/dev/null | _last_line_trim)"
  if [[ ! "$prefix" =~ ^[A-Za-z0-9_]+$ ]] \
     || ! grep -qE "CREATE TABLE (IF NOT EXISTS )?\`${prefix}options\`" "$PROJECT_DIR/tmp/$dump"; then
    prefix="$(sql_table_prefix "$PROJECT_DIR/tmp/$dump")"
  fi
  in_project wp db import "tmp/$dump" || return 1
  if [[ -n "$prefix" ]]; then
    in_project wp config set table_prefix "$prefix" --type=variable --quiet || return 1
  fi
  in_project wp search-replace "$REMOTE_URL" "$LOCAL_URL" --all-tables-with-prefix --quiet || return 1
  in_project wp rewrite flush --quiet || return 1
  log_success "db:pull done (dump kept in tmp/$dump)"
}

cmd_db_push() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: db:push (local export streamed → remote import → search-replace)"; return 0; fi
  project_context || return 1
  local lp rp stamp dump
  lp="$(in_project wp db prefix 2>/dev/null | _last_line_trim)"
  rp="$(_remote "wp db prefix" 2>/dev/null | _last_line_trim)"
  if [[ -z "$lp" || "$lp" != "$rp" ]]; then
    log_error "db:push: table prefix mismatch (local '$lp', remote '$rp'). Aborting."
    return 1
  fi
  log_warn "db:push OVERWRITES the remote database of $REMOTE_URL ($(_remote_target):$(_remote_app))"
  if [[ "$YES" != "true" ]] && ! confirm "Push the local DB to $REMOTE_URL ($(_remote_target):$(_remote_app))?"; then
    log_info "Aborted"
    return 1
  fi
  stamp="$(date '+%Y-%m-%d-%H%M')"
  dump="export-local-$stamp.sql"
  mkdir -p "$PROJECT_DIR/tmp" || return 1
  in_project wp db export "tmp/$dump" --quiet || return 1
  # Backup of the remote DB outside the web root.
  if ! _remote "mkdir -p ~/wpb-backups && wp db export ~/wpb-backups/pre-push-$stamp.sql --quiet"; then
    log_error "db:push: remote backup failed, aborting"; return 1
  fi
  log_info "db:push: remote DB backed up to ~/wpb-backups/pre-push-$stamp.sql"
  ssh "$(_remote_target)" "cd $(_remote_app) && wp db import - && wp search-replace '$LOCAL_URL' '$REMOTE_URL' --all-tables-with-prefix && wp rewrite flush" \
    < "$PROJECT_DIR/tmp/$dump" || return 1
  log_success "db:push done"
}

cmd_assets_pull() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: rsync remote uploads → local"; return 0; fi
  project_context || return 1
  rsync -azv --ignore-existing "$(_remote_target):$(_remote_app)/wp-content/uploads" "$PROJECT_DIR/wp-content"
}

cmd_plugins_pull() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: rsync remote plugins → local (missing files only)"; return 0; fi
  project_context || return 1
  local rc=0
  rsync -az --ignore-existing --exclude .git --exclude node_modules --exclude .DS_Store \
    "$(_remote_target):$(_remote_app)/wp-content/plugins/" "$PROJECT_DIR/wp-content/plugins/" || rc=$?
  # propagate rsync's exit code (23/24 = partial transfer, handled by the caller)
  (( rc == 0 )) || return "$rc"
  if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain wp-content/plugins 2>/dev/null)" ]]; then
    log_warn "Remote-only plugin files are now untracked locally — review before committing."
  fi
  log_success "plugins:pull done"
}

cmd_assets_push() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: rsync local uploads → remote"; return 0; fi
  project_context || return 1
  rsync -azv --ignore-existing "$PROJECT_DIR/wp-content/uploads" "$(_remote_target):$(_remote_app)/wp-content"
}

cmd_ssh() {
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: ssh into the remote app folder"; return 0; fi
  project_context || return 1
  ssh -t "$(_remote_target)" "cd $(_remote_app) && exec \$SHELL -l"
}
