#!/usr/bin/env bash
# lib/steps/plugins-pull.sh — `wpb get`: fill plugin files that are not versioned in git.

step_plugins_pull() {
  step_begin plugins_pull "fill untracked plugin files from remote (rsync)" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: wpb plugins:pull"; return 0; fi
  local rc=0
  cmd_plugins_pull || rc=$?
  case "$rc" in
    0) ;;
    23|24) log_warn "plugins:pull: partial transfer (rsync exit $rc) — some plugin files may be missing. Retry: cd $PROJECT_DIR && wpb plugins:pull" ;;
    *)
      log_error "plugins:pull failed — some plugin files (e.g. dist/) may be missing."
      log_error "When the remote is ready: cd $PROJECT_DIR && wpb plugins:pull"
      return 1 ;;
  esac
  step_done plugins_pull
}
