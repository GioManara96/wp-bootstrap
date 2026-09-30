#!/usr/bin/env bash
# lib/steps/starter-copy.sh — copy the starter (no .git) and rename its child theme to NAME.

step_starter_copy() {
  step_begin starter_copy "copy starter → $PROJECT_DIR" || return 0
  local child themes css tmp
  child="$(starter_child_theme "$STARTER_DIR")"
  [[ -n "$child" ]] || { log_error "starter: no child theme found in $STARTER_DIR"; return 1; }
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: rsync $STARTER_DIR/ → $PROJECT_DIR/; theme $child → $NAME"
    return 0
  fi
  mkdir -p "$PROJECT_DIR" || return 1
  state_init "$PROJECT_DIR"   # an interrupted copy stays resumable
  rsync -a --exclude .git --exclude node_modules --exclude .DS_Store "$STARTER_DIR/" "$PROJECT_DIR/" || return 1
  themes="$PROJECT_DIR/wp-content/themes"
  if [[ "$child" != "$NAME" ]]; then
    if [[ -d "$themes/$NAME" ]]; then rm -rf "${themes:?}/$child" || return 1   # forced re-run: keep existing theme
    else mv "$themes/$child" "$themes/$NAME" || return 1; fi
  fi
  css="$themes/$NAME/style.css"
  tmp="$(mktemp)"
  if ! substitute_template "$css" "$tmp" THEME_NAME "$NAME"; then rm -f "$tmp"; return 1; fi
  cat "$tmp" > "$css" && rm -f "$tmp" || return 1
  step_done starter_copy
}
