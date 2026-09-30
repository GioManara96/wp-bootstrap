#!/usr/bin/env bash
# lib/steps/env-file.sh — write the project .env.
#   new: LOCAL_URL + empty remote keys (the RunCloud app doesn't exist yet)
#   get: LOCAL_URL + prompt for the missing remote keys

step_env_file() {
  local mode="$1" envf="$PROJECT_DIR/.env" k
  step_begin env_file "project .env" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: write $envf"; return 0; fi
  penv_set "$envf" LOCAL_URL "$LOCAL_URL" || return 1
  if [[ "$mode" == "new" ]]; then
    for k in "${PENV_REMOTE_KEYS[@]}"; do
      [[ -n "$(penv_get "$envf" "$k")" ]] || penv_set "$envf" "$k" ""
    done
    log_info ".env: remote keys left empty — db:pull/db:push will ask for them"
  else
    local legacy
    for legacy in sync-operation.sh db-operation.sh; do
      if [[ -f "$PROJECT_DIR/$legacy" ]]; then
        log_info "Importing remote settings from $legacy"
        penv_import_legacy "$PROJECT_DIR/$legacy" "$envf"
        penv_set "$envf" LOCAL_URL "$LOCAL_URL" || return 1
        break
      fi
    done
    penv_ensure "$envf" "${PENV_REMOTE_KEYS[@]}" || return 1
  fi
  step_done env_file
}
