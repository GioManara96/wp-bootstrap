#!/usr/bin/env bash
# lib/steps/common.sh — skip-if-done helpers shared by every step.
# Steps read NAME, PROJECT_DIR, LOCAL_URL, DB_*, TABLE_PREFIX, GIT_URL, DRY_RUN, FORCE_STEP.

# step_begin <id> <description> — returns 1 when the step is done and not forced
step_begin() {
  local id="$1" desc="$2"
  if state_is_done "$PROJECT_DIR" "$id" && [[ "${FORCE_STEP:-}" != "$id" ]]; then
    log_step "$id" "$desc … SKIP (already done)"
    return 1
  fi
  log_step "$id" "$desc"
}

step_done() { state_mark_done "$PROJECT_DIR" "$1"; }

# in_project <cmd...> — run inside PROJECT_DIR
in_project() { ( cd "$PROJECT_DIR" && "$@" ); }
