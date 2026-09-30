#!/usr/bin/env bash
# lib/steps/core.sh — WordPress core, wp-config.php, .htaccess, tmp/.

step_core_download() {
  step_begin core_download "wp core download ($WP_LOCALE)" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: wp core download --locale=$WP_LOCALE --skip-content"; return 0; fi
  if [[ -f "$PROJECT_DIR/wp-load.php" ]]; then
    log_info "core_download: WordPress already present"
  elif ! in_project wp core download --locale="$WP_LOCALE" --skip-content --path=.; then
    # The locale package may not be published yet for the latest release.
    [[ "$WP_LOCALE" == "en_US" ]] && return 1
    log_warn "core_download: locale $WP_LOCALE not available, falling back to en_US"
    in_project wp core download --skip-content --force --path=. || return 1
  fi
  step_done core_download
}

_fetch_salts() { curl -fsS https://api.wordpress.org/secret-key/1.1/salt/; }

step_wp_config() {
  local target="$PROJECT_DIR/wp-config.php" salts
  step_begin wp_config "wp-config.php" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: render wp-config.template.php → $target"; return 0; fi
  if [[ -f "$target" && "${FORCE_STEP:-}" != "wp_config" ]]; then
    log_error "$target already exists. Remove it or use --force-step wp_config."
    return 1
  fi
  salts="$(_fetch_salts)" || { log_error "Failed to fetch salts from api.wordpress.org"; return 1; }
  substitute_template "$WPB_ROOT/templates/wp-config.template.php" "$target.tmp" \
    DB_NAME "$DB_NAME" DB_USER "$DB_USER" DB_PASSWORD "$DB_PASSWORD" DB_HOST localhost \
    TABLE_PREFIX "$TABLE_PREFIX" WP_MEMORY_LIMIT "$WP_MEMORY_LIMIT" SALTS_BLOCK "$salts" || { rm -f "$target.tmp"; return 1; }
  mv "$target.tmp" "$target" || return 1
  step_done wp_config
}

step_htaccess() {
  step_begin htaccess ".htaccess" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: copy htaccess.template if absent"; return 0; fi
  if [[ -f "$PROJECT_DIR/.htaccess" ]]; then
    log_info "htaccess: keeping existing file"
  else
    cp "$WPB_ROOT/templates/htaccess.template" "$PROJECT_DIR/.htaccess" || return 1
  fi
  step_done htaccess
}

step_tmp_folder() {
  step_begin tmp_folder "tmp/" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: mkdir -p tmp"; return 0; fi
  mkdir -p "$PROJECT_DIR/tmp" || return 1
  step_done tmp_folder
}
