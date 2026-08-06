#!/usr/bin/env bash
# lib/steps/04-wp-config.sh

_fetch_salts() {
  curl -fsS https://api.wordpress.org/secret-key/1.1/salt/
}

step_04_wp_config() {
  local id="04_wp_config"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local target="$project_dir/wp-config.php"
  local template="$SCRIPT_ROOT/templates/wp-config.template.php"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "04" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 04 "wp-config … SKIP (already done)"
    return 0
  fi

  if [[ -f "$target" && "$force_this" != "true" ]]; then
    log_error "$target already exists. Use --force, --force-step 04, or --resume."
    return 1
  fi

  log_step 04 "wp-config: generating $target"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: fetch salts + substitute_template $template → $target"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  local salts
  salts="$(_fetch_salts)" || { log_error "Failed to fetch salts from api.wordpress.org"; return 1; }

  substitute_template "$template" "$target" \
    DB_NAME "$DB_NAME" \
    DB_USER "$DB_USER" \
    DB_PASSWORD "$DB_PASSWORD" \
    DB_HOST "localhost" \
    TABLE_PREFIX "$TABLE_PREFIX" \
    WP_MEMORY_LIMIT "$DEFAULT_WP_MEMORY_LIMIT" \
    SALTS_BLOCK "$salts" || return 1

  state_mark_done "$project_dir" "$id"
}
