#!/usr/bin/env bash
# lib/steps/08-frontend-tools.sh

step_08_frontend_tools() {
  local id="08_frontend_tools"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$project_dir/frontend_tools"
  local source_dir="$SCRIPT_ROOT/templates/frontend_tools"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "08" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 08 "frontend-tools … SKIP (already done)"
    return 0
  fi

  if [[ -d "$target" ]]; then
    if [[ "$force_this" == "true" ]]; then
      log_warn "Removing existing $target (--force)"
      if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: rm -rf $target"
      else
        rm -rf "$target"
      fi
    else
      log_error "$target already exists. Use --force, --force-step 08, or --resume."
      return 1
    fi
  fi

  log_step 08 "frontend-tools: copying scaffold"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: rsync -a $source_dir/ $target/"
    log_info "DRY-RUN: (cd $target && nvm use 20.19 && npm install)"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  rsync -a "$source_dir/" "$target/" || return 1

  # Activate node 20.19 if nvm is available
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.nvm/nvm.sh"
    ( cd "$target" && nvm use 2>/dev/null || nvm install 20.19 && nvm use 20.19 ) || \
      log_warn "nvm use failed; will try with current node"
  else
    log_warn "nvm not found at \$HOME/.nvm/nvm.sh; using current node version"
  fi

  log_step 08 "frontend-tools: npm install (this can take a few minutes)"
  ( cd "$target" && npm install ) || return 1

  state_mark_done "$project_dir" "$id"
}
