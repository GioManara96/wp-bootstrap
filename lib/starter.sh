#!/usr/bin/env bash
# lib/starter.sh — locate and validate the starter in the private companion repo.
# Requires lib/utils.sh and lib/versions.sh.

starter_dir() { printf '%s/starter' "${STARTER_REPO%/}"; }

# starter_child_theme <starter-dir> — the single theme whose style.css has "Template:"
starter_child_theme() {
  local css
  local -a found=()
  for css in "$1"/wp-content/themes/*/style.css; do
    [[ -f "$css" ]] || continue
    grep -qi '^[[:space:]/*#@]*Template:' "$css" && found+=("$(basename "$(dirname "$css")")")
  done
  (( ${#found[@]} == 1 )) && printf '%s' "${found[0]}"
}

# starter_validate <starter-dir>
starter_validate() {
  local d="$1" p
  local -a missing=()
  for p in wp-content .gitignore .env.example; do [[ -e "$d/$p" ]] || missing+=("$p"); done
  if (( ${#missing[@]} )); then
    log_error "Invalid starter $d — missing: ${missing[*]}"
    return 1
  fi
  if [[ -z "$(starter_child_theme "$d")" ]]; then
    log_error "Invalid starter $d — need exactly one child theme (style.css with 'Template:') in wp-content/themes"
    return 1
  fi
}

# starter_require — sets STARTER_DIR from STARTER_REPO and validates it
starter_require() {
  if [[ -z "${STARTER_REPO:-}" ]]; then
    log_error "No starter configured — run 'wpb setup' and set the internal repo path."
    return 1
  fi
  STARTER_DIR="$(starter_dir)"
  starter_validate "$STARTER_DIR"
}

# starter_best_candidate <plugins|themes> <slug> <current-version>
# Prints "<version>\t<path>" of the highest version above current found under
# SITES_DIR/*/wp-content/<kind>/<slug>; prints nothing when the starter is newest.
starter_best_candidate() {
  local kind="$1" slug="$2" best="$3" best_path="" cand v
  for cand in "$SITES_DIR"/*/wp-content/"$kind"/"$slug"; do
    [[ -d "$cand" ]] || continue
    if [[ "$kind" == "plugins" ]]; then v="$(plugin_version "$cand")"; else v="$(theme_version "$cand")"; fi
    [[ -n "$v" ]] || continue
    [[ "$v" =~ [Aa][Ll][Pp][Hh][Aa]|[Bb][Ee][Tt][Aa]|[Rr][Cc]|[Dd][Ee][Vv] ]] && continue
    if version_gt "$v" "$best"; then best="$v"; best_path="$cand"; fi
  done
  [[ -n "$best_path" ]] && printf '%s\t%s\n' "$best" "$best_path"
  return 0
}
