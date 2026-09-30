#!/usr/bin/env bash
# lib/commands/get.sh — wpb get <gitlab-url>: existing project → local.

cmd_get() {
  if [[ -z "${1:-}" ]]; then log_error "Usage: wpb get <gitlab-url> [--name <name>] [--no-pull]"; return 1; fi
  config_require || return 1
  project_init_vars "$1" || return 1
  preflight_project_dir || return 1
  preflight_vhost_free || return 1
  _get_steps || { project_rerun_hint get; return 1; }
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN complete for $NAME"; return 0; fi
  print_summary get
}

_get_steps() {
  step_clone || return 1
  step_git_exclude || return 1
  step_frontend_tools || return 1
  step_env_file get || return 1
  step_core_download || return 1
  step_db_create || return 1
  step_wp_config || return 1
  step_htaccess || return 1
  step_tmp_folder || return 1
  if [[ "$NO_PULL" == "true" ]]; then
    log_info "Skipping plugins:pull and db:pull (--no-pull). Later: cd $PROJECT_DIR && wpb plugins:pull && wpb db:pull"
  else
    step_plugins_pull || return 1
    step_first_pull || return 1
  fi
}
