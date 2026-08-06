#!/usr/bin/env bash
# lib/steps/07-sync-script.sh

step_07_sync_script() {
  local id="07_sync_script"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$project_dir/sync-operation.sh"
  local template="$SCRIPT_ROOT/templates/sync-operation.template.sh"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "07" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 07 "sync-script … SKIP (already done)"
    return 0
  fi

  if [[ -f "$target" && "$force_this" != "true" ]]; then
    log_error "$target already exists. Use --force, --force-step 07, or --resume."
    return 1
  fi

  log_step 07 "sync-script: generating $target"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: substitute_template $template → $target (RC_USER=$SSH_USER ...)"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  local remote_url="https://$REMOTE_DOMAIN"
  local local_url="http://$LOCAL_DOMAIN"

  substitute_template "$template" "$target" \
    RC_USER       "$SSH_USER" \
    RC_APP_NAME   "$RC_APP_NAME" \
    W_URL_REMOTE  "$remote_url" \
    RC_SERVERNAME "$SSH_HOST" \
    W_URL_LOCAL   "$local_url" || return 1

  chmod +x "$target"

  state_mark_done "$project_dir" "$id"
}
