#!/usr/bin/env bash
# lib/steps/11-restart-httpd.sh

step_11_restart_httpd() {
  local id="11_restart_httpd"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"

  # Always runs (idempotent)
  log_step 11 "restart-httpd: brew services restart httpd"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: brew services restart httpd"
  else
    brew services restart httpd || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
