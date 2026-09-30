#!/usr/bin/env bash
# lib/steps/first-pull.sh — `wpb get`: first db:pull from the remote.

step_first_pull() {
  step_begin first_pull "db:pull from remote" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: wpb db:pull"; return 0; fi
  if ! cmd_db_pull; then
    log_error "db:pull failed — the site is set up with an empty DB."
    log_error "When the remote is ready: cd $PROJECT_DIR && wpb db:pull"
    return 1
  fi
  step_done first_pull
}
