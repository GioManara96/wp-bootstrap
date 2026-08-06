#!/usr/bin/env bash
# lib/steps/04c-plugins.sh
#
# - Delete default plugins (akismet, hello)
# - Install + activate the curated plugin set

_DEFAULT_WP_PLUGINS_TO_DELETE=(
  akismet
  hello
)

# Plugins installed and activated for every new site. Slugs must match
# wordpress.org/plugins/<slug>.
_PLUGINS_TO_INSTALL=(
  elementor
  better-wp-security
  seo-by-rank-math
  disable-comments
  contact-form-7
  wpcf7-redirect
  advanced-custom-fields
  webp-express
  wps-hide-login
  google-site-kit
  indexnow
  worker
  wp-mail-smtp
)

step_04c_plugins() {
  local id="04c_plugins"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "04c" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 04c "plugins … SKIP (already done)"
    return 0
  fi

  log_step 04c "plugins: delete defaults, install + activate ${#_PLUGINS_TO_INSTALL[@]} plugins"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: wp plugin delete ${_DEFAULT_WP_PLUGINS_TO_DELETE[*]}"
    log_info "DRY-RUN: wp plugin install --activate: ${_PLUGINS_TO_INSTALL[*]}"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  # Delete defaults (ignore missing)
  ( cd "$project_dir" && wp plugin delete "${_DEFAULT_WP_PLUGINS_TO_DELETE[@]}" --path=. 2>/dev/null ) || true

  # Install + activate one at a time so a single failure doesn't abort the batch.
  local plugin failed=()
  for plugin in "${_PLUGINS_TO_INSTALL[@]}"; do
    if ( cd "$project_dir" && wp plugin install "$plugin" --activate --path=. ); then
      log_success "plugin OK: $plugin"
    else
      log_warn "plugin FAILED: $plugin (continuing)"
      failed+=("$plugin")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_warn "Plugins that failed to install/activate: ${failed[*]}"
    log_warn "Install them manually via wp-admin or 'wp plugin install <slug>'"
  fi

  state_mark_done "$project_dir" "$id"
}
