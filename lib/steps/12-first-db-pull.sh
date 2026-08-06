#!/usr/bin/env bash
# lib/steps/12-first-db-pull.sh

step_12_first_db_pull() {
  local id="12_first_db_pull"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"

  if [[ "$SKIP_PULL" == "true" ]]; then
    log_step 12 "first-db-pull … SKIPPED (--skip-pull)"
    return 0
  fi

  if state_is_done "$project_dir" "$id" && [[ "$FORCE" != "true" && "$FORCE_STEP" != "12" ]]; then
    log_step 12 "first-db-pull … SKIP (already done)"
    return 0
  fi

  log_step 12 "first-db-pull: ./sync-operation.sh db:pull"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: (cd $project_dir && ./sync-operation.sh db:pull)"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  ( cd "$project_dir" && ./sync-operation.sh db:pull ) || {
    log_error "db:pull failed. The local site is set up but DB is still empty."
    log_error "When the remote is ready, run from $project_dir:  ./sync-operation.sh db:pull"
    log_error "Or re-run bootstrap with: wp-bootstrap --resume --force-step 12"
    return 1
  }

  state_mark_done "$project_dir" "$id"
}
