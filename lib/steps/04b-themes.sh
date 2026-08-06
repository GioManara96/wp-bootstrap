#!/usr/bin/env bash
# lib/steps/04b-themes.sh
#
# - Delete default WP bundled themes
# - Install Astra (parent)
# - Copy templates/child-theme/ → wp-content/themes/$THEME_NAME/
# - Substitute {{THEME_NAME}} in child style.css
# - Activate child theme

# Default themes that ship with WordPress (across versions). We delete all
# present; missing ones produce a warning that we swallow.
_DEFAULT_WP_THEMES=(
  twentytwentyone
  twentytwentytwo
  twentytwentythree
  twentytwentyfour
  twentytwentyfive
  twentytwentysix
)

step_04b_themes() {
  local id="04b_themes"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local child_target="$project_dir/wp-content/themes/$THEME_NAME"
  local template_dir="$SCRIPT_ROOT/templates/child-theme"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "04b" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 04b "themes … SKIP (already done)"
    return 0
  fi

  log_step 04b "themes: cleanup defaults, install Astra, activate child '$THEME_NAME'"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: wp theme delete ${_DEFAULT_WP_THEMES[*]}"
    log_info "DRY-RUN: wp theme install astra"
    log_info "DRY-RUN: rsync -a $template_dir/ $child_target/  (substitute THEME_NAME=$THEME_NAME in style.css)"
    log_info "DRY-RUN: wp theme activate $THEME_NAME"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  # 1. Delete default WP themes (ignore missing)
  ( cd "$project_dir" && wp theme delete "${_DEFAULT_WP_THEMES[@]}" --path=. 2>/dev/null ) || true

  # 2. Install Astra parent (no activate — child takes over)
  ( cd "$project_dir" && wp theme install astra --path=. ) || {
    log_error "Failed to install Astra parent theme"
    return 1
  }

  # 3. If child theme dir already exists and --force, wipe it
  if [[ -d "$child_target" ]]; then
    if [[ "$force_this" == "true" ]]; then
      log_warn "Removing existing $child_target (--force)"
      rm -rf "$child_target"
    else
      log_error "Child theme dir $child_target already exists. Use --force, --force-step 04b, or --resume."
      return 1
    fi
  fi

  # 4. Copy template (preserve structure exactly)
  rsync -a "$template_dir/" "$child_target/" || return 1

  # 5. Substitute THEME_NAME placeholder in style.css
  local tmp_style
  tmp_style="$(mktemp)"
  substitute_template "$child_target/style.css" "$tmp_style" THEME_NAME "$THEME_NAME" || {
    rm -f "$tmp_style"
    return 1
  }
  mv "$tmp_style" "$child_target/style.css"

  # 6. Activate child theme
  ( cd "$project_dir" && wp theme activate "$THEME_NAME" --path=. ) || {
    log_error "Failed to activate child theme $THEME_NAME"
    return 1
  }

  state_mark_done "$project_dir" "$id"
}
