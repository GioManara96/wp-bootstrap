#!/usr/bin/env bash
# lib/steps/wp-install.sh — `wpb new` only: install WP, language, permalinks, activate starter.

step_wp_install() {
  step_begin wp_install "wp core install + language + permalinks + activate theme/plugins" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: wp core install --url=$LOCAL_URL (admin/admin); activate theme $NAME + all plugins"
    return 0
  fi
  if ! in_project wp core is-installed 2>/dev/null; then
    in_project wp core install --url="$LOCAL_URL" --title="$NAME" --admin_user=admin \
      --admin_password=admin --admin_email=admin@example.com --skip-email || return 1
  fi
  _install_core_language
  in_project wp rewrite structure '/%postname%/' --hard --quiet || log_warn "wp_install: permalink setup failed"
  in_project wp theme activate "$NAME" || return 1
  # Alphabetical activation can hit a plugin before its dependency: a second pass fixes that.
  if ! in_project wp plugin activate --all; then
    in_project wp plugin activate --all || log_warn "wp_install: some plugins failed to activate — check wp-admin"
  fi
  step_done wp_install
}

# Non-blocking: core_download may have fallen back to en_US.
_install_core_language() {
  [[ -z "${WP_LOCALE:-}" || "$WP_LOCALE" == "en_US" ]] && return 0
  if in_project wp language core install "$WP_LOCALE" --activate; then
    log_success "wp_install: language $WP_LOCALE active"
  else
    log_warn "wp_install: language $WP_LOCALE not available yet — later: wp language core install $WP_LOCALE --activate"
  fi
}
