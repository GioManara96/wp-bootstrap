#!/usr/bin/env bash
# wp-bootstrap.sh — entry point

set -uo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
# shellcheck source=lib/utils.sh
source "$SCRIPT_ROOT/lib/utils.sh"
# shellcheck source=lib/state.sh
source "$SCRIPT_ROOT/lib/state.sh"
# shellcheck source=lib/prereqs.sh
source "$SCRIPT_ROOT/lib/prereqs.sh"
# shellcheck source=lib/inputs.sh
source "$SCRIPT_ROOT/lib/inputs.sh"

# Load step files
for step_file in "$SCRIPT_ROOT/lib/steps/"*.sh; do
  # shellcheck source=/dev/null
  source "$step_file"
done

# Smoke test (post-step-11)
_smoke_test() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: skipping smoke test (curl + wp db check)"
    return 0
  fi
  log_info "Running smoke test"
  local url="http://$LOCAL_DOMAIN"
  if curl -sI -o /dev/null --max-time 5 "$url"; then
    log_success "smoke: $url responds"
  else
    log_warn "smoke: $url did not respond (curl). Check Apache config / DNS."
  fi
  if ( cd "$DEFAULT_SITES_DIR/$NAME" && wp db check 2>/dev/null ); then
    log_success "smoke: wp db check OK"
  else
    log_warn "smoke: wp db check failed (DB may still be empty if --skip-pull)"
  fi
}

_post_success() {
  cat >&2 <<EOF

============================================================
wp-bootstrap — Done
============================================================
  Local site:   http://$LOCAL_DOMAIN
  Admin URL:    http://$LOCAL_DOMAIN/wp-admin
  Project dir:  $DEFAULT_SITES_DIR/$NAME

Remaining manual TODOs:
  1. Configure GitLab → RunCloud webhook for auto-deploy
EOF
  if [[ "$SKIP_PULL" == "true" ]]; then
    cat >&2 <<EOF
  2. When the remote site is ready:
     cd $DEFAULT_SITES_DIR/$NAME && ./sync-operation.sh db:pull
  3. Or run: wp-bootstrap --resume   (to perform the first pull now)
EOF
  fi
  cat >&2 <<EOF
============================================================
EOF
}

_error_hint() {
  local exit_code=$?
  local lineno=${BASH_LINENO[0]:-?}
  cat >&2 <<EOF

============================================================
wp-bootstrap — FAILED at line $lineno (exit $exit_code)
============================================================
State saved at: $DEFAULT_SITES_DIR/$NAME/.bootstrap-state (if step 01 completed)

To resume after fixing the issue:
  wp-bootstrap --resume

To force a single step:
  cd $DEFAULT_SITES_DIR/$NAME && wp-bootstrap --force-step <NN>

To start over from scratch:
  wp-bootstrap --force --yes
============================================================
EOF
  exit $exit_code
}

main() {
  trap '_error_hint' ERR

  parse_flags "$@" || exit 1
  load_env "$SCRIPT_ROOT/.env" || exit 1
  check_prereqs || exit 1
  resolve_inputs || exit 1

  # Execute steps in order. Step 01 creates the project dir; afterwards we persist
  # .bootstrap.yml and initialize .bootstrap-state.
  step_01_clone_repo

  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  state_init "$project_dir"
  save_bootstrap_yml "$project_dir"
  state_mark_done "$project_dir" "01_clone_repo"

  step_02_download_wp
  step_03_create_db
  step_04_wp_config
  step_04a_wp_core_install
  step_04b_themes
  step_04c_plugins
  step_05_htaccess
  step_06_tmp_folder
  step_07_sync_script
  step_08_frontend_tools
  step_09_vhost
  step_10_logs_folder
  step_11_restart_httpd
  _smoke_test
  step_12_first_db_pull

  _post_success
}

main "$@"
