#!/usr/bin/env bash
# lib/commands/starter-refresh.sh — copy the newest plugin/theme versions found in SITES_DIR
# into the starter. No network, no licenses; the user reviews and commits.

cmd_starter_refresh() {
  starter_require || return 1
  local child kind dir slug cur line v src i
  local -a upd_src=() upd_dst=()
  child="$(starter_child_theme "$STARTER_DIR")"
  printf '%-45s %-12s %-12s %s\n' "ITEM" "STARTER" "FOUND" "FROM"
  for kind in plugins themes; do
    for dir in "$STARTER_DIR/wp-content/$kind"/*/; do
      [[ -d "$dir" ]] || continue
      dir="${dir%/}"
      slug="$(basename "$dir")"
      [[ "$kind" == "themes" && "$slug" == "$child" ]] && continue
      if [[ "$kind" == "plugins" ]]; then cur="$(plugin_version "$dir")"; else cur="$(theme_version "$dir")"; fi
      line="$(starter_best_candidate "$kind" "$slug" "$cur")"
      [[ -n "$line" ]] || continue
      v="${line%%$'\t'*}"
      src="${line#*$'\t'}"
      printf '%-45s %-12s %-12s %s\n' "$kind/$slug" "${cur:-?}" "$v" "${src#"$SITES_DIR"/}"
      upd_src+=("$src")
      upd_dst+=("$dir")
    done
  done
  if (( ${#upd_src[@]} == 0 )); then
    log_success "Starter is up to date"
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: nothing copied"; return 0; fi
  if [[ "$YES" != "true" ]] && ! confirm "Copy ${#upd_src[@]} newer item(s) into the starter?"; then
    log_info "Aborted"
    return 1
  fi
  for i in "${!upd_src[@]}"; do
    rsync -a --checksum --delete --exclude .git --exclude node_modules --exclude .DS_Store "${upd_src[$i]}/" "${upd_dst[$i]}/" || return 1
  done
  log_success "Starter updated — review with 'git -C $STARTER_REPO status', then commit"
}
