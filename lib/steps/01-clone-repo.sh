#!/usr/bin/env bash
# lib/steps/01-clone-repo.sh

step_01_clone_repo() {
  local id="01_clone_repo"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "01" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 01 "clone-repo … SKIP (already done)"
    return 0
  fi

  if [[ -d "$project_dir" ]]; then
    if [[ "$force_this" == "true" ]]; then
      log_warn "Removing existing $project_dir (--force)"
      if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: rm -rf $project_dir"
      else
        rm -rf "$project_dir"
      fi
    else
      log_error "Directory $project_dir already exists. Use --force, --force-step 01, or --resume."
      return 1
    fi
  fi

  log_step 01 "clone-repo: git clone $GITLAB_URL → $project_dir"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: git clone $GITLAB_URL $project_dir"
  else
    git clone "$GITLAB_URL" "$project_dir" || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
