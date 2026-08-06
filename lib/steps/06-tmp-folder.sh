#!/usr/bin/env bash
# lib/steps/06-tmp-folder.sh

step_06_tmp_folder() {
  local id="06_tmp_folder"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$project_dir/tmp"

  if state_is_done "$project_dir" "$id" && [[ "$FORCE" != "true" && "$FORCE_STEP" != "06" ]]; then
    log_step 06 "tmp-folder … SKIP (already done)"
    return 0
  fi

  log_step 06 "tmp-folder: mkdir -p $target"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: mkdir -p $target"
  else
    mkdir -p "$target" || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
