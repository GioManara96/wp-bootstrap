#!/usr/bin/env bash
# lib/steps/04a-wp-core-install.sh
#
# Creates WordPress tables and admin user so subsequent steps (theme/plugin
# activation) can write to the DB. Idempotent: skipped if WP is already
# installed in the target DB. With --skip-pull, this is the final state.
# Without --skip-pull, step 12 (db:pull) will overwrite everything.

step_04a_wp_core_install() {
  local id="04a_wp_core_install"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "04a" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 04a "wp-core-install … SKIP (already done)"
    return 0
  fi

  log_step 04a "wp-core-install: wp core install (admin / admin)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: wp core install --url=http://$LOCAL_DOMAIN --title='$NAME' --admin_user=admin --admin_password=admin --admin_email=$DEFAULT_VHOST_EMAIL"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  if ( cd "$project_dir" && wp core is-installed --path=. 2>/dev/null ); then
    log_info "wp-core-install: already installed in DB, skipping"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  ( cd "$project_dir" && wp core install \
      --url="http://$LOCAL_DOMAIN" \
      --title="$NAME" \
      --admin_user=admin \
      --admin_password=admin \
      --admin_email="$DEFAULT_VHOST_EMAIL" \
      --skip-email \
      --path=. ) || return 1

  _install_core_language "$project_dir"

  state_mark_done "$project_dir" "$id"
}

# Ensures DEFAULT_WP_LOCALE is installed and active. Non-blocking: step 02 may
# have fallen back to en_US because the language pack isn't published yet.
_install_core_language() {
  local project_dir="$1"
  [[ -z "${DEFAULT_WP_LOCALE:-}" || "$DEFAULT_WP_LOCALE" == "en_US" ]] && return 0

  if ( cd "$project_dir" && wp language core install "$DEFAULT_WP_LOCALE" --activate --path=. ); then
    log_success "wp-core-install: language $DEFAULT_WP_LOCALE active"
  else
    log_warn "wp-core-install: language $DEFAULT_WP_LOCALE not available for this WP version, site left in en_US."
    log_warn "  Install it later with: wp language core install $DEFAULT_WP_LOCALE --activate"
  fi
}
