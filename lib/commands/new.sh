#!/usr/bin/env bash
# lib/commands/new.sh — wpb new <gitlab-url>: starter → new project → first push.

cmd_new() {
  if [[ -z "${1:-}" ]]; then log_error "Usage: wpb new <empty-gitlab-repo-url> [--name <name>]"; return 1; fi
  config_require || return 1
  starter_require || return 1
  project_init_vars "$1" || return 1
  preflight_project_dir || return 1
  preflight_vhost_free || return 1
  if [[ ! -f "$PROJECT_DIR/.bootstrap-state" ]]; then
    preflight_remote_empty "$GIT_URL" || return 1
  fi
  _new_steps || { project_rerun_hint new; return 1; }
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN complete for $NAME"; return 0; fi
  print_summary new
}

_new_steps() {
  step_starter_copy || return 1
  step_git_init || return 1
  step_git_exclude || return 1
  step_frontend_tools || return 1
  step_env_file new || return 1
  step_core_download || return 1
  step_db_create || return 1
  step_wp_config || return 1
  step_htaccess || return 1
  step_tmp_folder || return 1
  step_wp_install || return 1
  step_first_push || return 1
}
