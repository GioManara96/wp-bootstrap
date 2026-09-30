#!/usr/bin/env bash
# lib/state.sh — manages .bootstrap-state file (key=value).
# All mutating functions are no-ops when DRY_RUN=true or when the project
# directory doesn't exist yet (e.g. before the project folder exists).

_state_file() { printf '%s/.bootstrap-state' "$1"; }

# state_init <project-dir>
state_init() {
  [[ "${DRY_RUN:-false}" == "true" ]] && return 0
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local f
  f="$(_state_file "$dir")"
  if [[ ! -f "$f" ]]; then
    : > "$f"
  fi
}

# state_is_done <project-dir> <step-id>  → returns 0 if done, 1 if not
state_is_done() {
  local f
  f="$(_state_file "$1")"
  [[ -f "$f" ]] || return 1
  grep -q "^${2}=done$" "$f"
}

# state_mark_done <project-dir> <step-id>
state_mark_done() {
  [[ "${DRY_RUN:-false}" == "true" ]] && return 0
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local f
  f="$(_state_file "$dir")"
  state_init "$dir"
  # Remove existing line for this step (if any), then append.
  if grep -q "^${2}=" "$f" 2>/dev/null; then
    grep -v "^${2}=" "$f" > "${f}.tmp"
    mv "${f}.tmp" "$f"
  fi
  printf '%s=done\n' "$2" >> "$f"
}

# state_clear <project-dir> <step-id>
state_clear() {
  [[ "${DRY_RUN:-false}" == "true" ]] && return 0
  local f
  f="$(_state_file "$1")"
  [[ -f "$f" ]] || return 0
  grep -v "^${2}=" "$f" > "${f}.tmp" || true
  mv "${f}.tmp" "$f"
}
