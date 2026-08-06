#!/usr/bin/env bash
# lib/steps/05-htaccess.sh

step_05_htaccess() {
  local id="05_htaccess"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$project_dir/.htaccess"
  local template="$SCRIPT_ROOT/templates/htaccess.template"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "05" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 05 "htaccess … SKIP (already done)"
    return 0
  fi

  if [[ -f "$target" && "$force_this" != "true" ]]; then
    log_error "$target already exists. Use --force, --force-step 05, or --resume."
    return 1
  fi

  log_step 05 "htaccess: writing $target"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: cp $template $target"
  else
    cp "$template" "$target" || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
