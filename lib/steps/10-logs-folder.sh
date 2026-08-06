#!/usr/bin/env bash
# lib/steps/10-logs-folder.sh

step_10_logs_folder() {
  local id="10_logs_folder"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$DEFAULT_SITES_DIR/logs"

  if state_is_done "$project_dir" "$id" && [[ "$FORCE" != "true" && "$FORCE_STEP" != "10" ]]; then
    log_step 10 "logs-folder … SKIP (already done)"
    return 0
  fi

  log_step 10 "logs-folder: mkdir -p $target"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: mkdir -p $target"
  else
    mkdir -p "$target" || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
