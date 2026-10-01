#!/usr/bin/env bash
# lib/steps/code-pull.sh — `wpb adopt`: copy themes, plugins and mu-plugins from the live site.

step_code_pull() {
  local envf="$PROJECT_DIR/.env" rc=0
  step_begin code_pull "copy themes, plugins, mu-plugins from remote (rsync)" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: rsync remote wp-content/{themes,plugins,mu-plugins} → local"; return 0; fi
  penv_load "$envf"
  _validate_remote_config "$envf" || return 1
  # rsync reports a missing source as a partial transfer (23): check it first
  if ! _remote "test -d wp-content/themes" </dev/null; then
    log_error "code_pull: no WordPress in $(_remote_target):$(_remote_app) — check REMOTE_APP_NAME / REMOTE_SSH_* in $envf"
    return 1
  fi
  mkdir -p "$PROJECT_DIR/wp-content" || return 1
  rsync -az --exclude .git --exclude node_modules --exclude .DS_Store \
    --include '/plugins/***' --include '/themes/***' --include '/mu-plugins/***' --exclude '*' \
    "$(_remote_target):$(_remote_app)/wp-content/" "$PROJECT_DIR/wp-content/" || rc=$?
  case "$rc" in
    0) ;;
    23|24) log_warn "code_pull: partial transfer (rsync exit $rc) — some files may be missing. Retry: wpb adopt … --force-step code_pull" ;;
    *) log_error "code_pull: rsync from $(_remote_target):$(_remote_app)/wp-content failed (exit $rc)"; return 1 ;;
  esac
  step_done code_pull
}
