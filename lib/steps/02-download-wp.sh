#!/usr/bin/env bash
# lib/steps/02-download-wp.sh

step_02_download_wp() {
  local id="02_download_wp"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "02" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 02 "download-wp … SKIP (already done)"
    return 0
  fi

  if [[ -f "$project_dir/wp-load.php" && "$force_this" != "true" ]]; then
    log_error "WordPress already present in $project_dir. Use --force, --force-step 02, or --resume."
    return 1
  fi

  local force_flag=""
  $force_this && force_flag="--force"

  log_step 02 "download-wp: wp core download --locale=$DEFAULT_WP_LOCALE"
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: (cd $project_dir && wp core download --locale=$DEFAULT_WP_LOCALE --path=. $force_flag)"
  elif ! ( cd "$project_dir" && wp core download --locale="$DEFAULT_WP_LOCALE" --path=. $force_flag ); then
    # The locale package may not be published yet for the latest WP release.
    # Fall back to en_US; step 04a tries to install the language pack afterwards.
    [[ "$DEFAULT_WP_LOCALE" == "en_US" ]] && return 1
    log_warn "download-wp: locale $DEFAULT_WP_LOCALE not available, falling back to en_US"
    ( cd "$project_dir" && wp core download --path=. --force ) || return 1
  fi

  state_mark_done "$project_dir" "$id"
}
