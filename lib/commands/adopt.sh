#!/usr/bin/env bash
# lib/commands/adopt.sh — wpb adopt [<gitlab-url>]: a site live on RunCloud with no git → local.
# Code (themes, plugins, mu-plugins) and DB come from the server. With an empty repo URL the
# project gets its first push there; without one it stays local (e.g. just to test a site).

cmd_adopt() {
  config_require || return 1
  project_init_vars "${1:-}" || {
    log_error "Usage: wpb adopt [<empty-gitlab-repo-url>] [--name <name>] (--name required without a URL)"
    return 1
  }
  preflight_project_dir || return 1
  preflight_vhost_free || return 1
  if [[ "$DRY_RUN" == "true" ]]; then
    [[ -z "$GIT_URL" ]] || log_info "DRY-RUN: git ls-remote $GIT_URL (must be empty)"
  elif [[ -n "$GIT_URL" && ! -f "$PROJECT_DIR/.bootstrap-state" ]]; then
    preflight_remote_empty "$GIT_URL" || return 1
  fi
  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "$PROJECT_DIR" || return 1
    state_init "$PROJECT_DIR"
  fi
  FIRST_COMMIT_MSG="Import live site from RunCloud"
  _adopt_steps || { project_rerun_hint adopt; return 1; }
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN complete for $NAME"; return 0; fi
  print_summary adopt
}

_adopt_steps() {
  step_git_init || return 1
  step_git_exclude || return 1
  step_gitignore || return 1
  step_env_file get || return 1
  step_code_pull || return 1
  step_core_download || return 1
  step_db_create || return 1
  step_wp_config || return 1
  step_htaccess || return 1
  step_tmp_folder || return 1
  step_first_pull || return 1
  if [[ -n "$GIT_URL" ]]; then
    step_first_push || return 1
  else
    log_info "No repo URL: local git only, nothing pushed."
  fi
}
