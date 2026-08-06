#!/usr/bin/env bash
# lib/inputs.sh — flag parsing, env loading, prompts, priority resolution

# All input variables (resolved value goes here regardless of source)
: "${NAME:=}"
: "${GITLAB_URL:=}"
: "${REMOTE_DOMAIN:=}"
: "${SSH_USER:=}"
: "${SSH_HOST:=}"
: "${RC_APP_NAME:=}"
: "${DB_NAME:=}"
: "${DB_USER:=}"
: "${DB_PASSWORD:=}"
: "${TABLE_PREFIX:=}"
: "${LOCAL_DOMAIN:=}"
: "${THEME_NAME:=}"
: "${FROM_FILE:=}"
: "${RESUME:=false}"
: "${FORCE:=false}"
: "${FORCE_STEP:=}"
: "${SKIP_PULL:=false}"
: "${DRY_RUN:=false}"
: "${YES:=false}"

# Defaults from .env
: "${MYSQL_ADMIN_USER:=}"
: "${MYSQL_ADMIN_PASSWORD:=}"
: "${DEFAULT_VHOST_EMAIL:=}"
: "${DEFAULT_SITES_DIR:=$HOME/Sites}"
: "${DEFAULT_APACHE_VHOST_FILE:=/opt/homebrew/etc/httpd/extra/httpd-vhost.conf}"
: "${DEFAULT_WP_LOCALE:=it_IT}"
: "${DEFAULT_WP_MEMORY_LIMIT:=768M}"

# parse_flags <args...> — sets global vars from CLI flags
parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)            NAME="$2";          shift 2 ;;
      --gitlab-url)      GITLAB_URL="$2";    shift 2 ;;
      --remote-domain)   REMOTE_DOMAIN="$2"; shift 2 ;;
      --ssh-user)        SSH_USER="$2";      shift 2 ;;
      --ssh-host)        SSH_HOST="$2";      shift 2 ;;
      --rc-app-name)     RC_APP_NAME="$2";   shift 2 ;;
      --db-name)         DB_NAME="$2";       shift 2 ;;
      --db-user)         DB_USER="$2";       shift 2 ;;
      --db-password)     DB_PASSWORD="$2";   shift 2 ;;
      --table-prefix)    TABLE_PREFIX="$2";  shift 2 ;;
      --local-domain)    LOCAL_DOMAIN="$2";  shift 2 ;;
      --theme-name)      THEME_NAME="$2";    shift 2 ;;
      --from-file)       FROM_FILE="$2";     shift 2 ;;
      --force-step)      FORCE_STEP="$2";    shift 2 ;;
      --resume)          RESUME=true;        shift ;;
      --force)           FORCE=true;         shift ;;
      --skip-pull)       SKIP_PULL=true;     shift ;;
      --dry-run)         DRY_RUN=true;       shift ;;
      --yes)             YES=true;           shift ;;
      --help|-h)         print_help; exit 0 ;;
      *)
        log_error "Unknown flag: $1"
        print_help
        return 1
        ;;
    esac
  done
}

# load_env <path> — sources .env safely; fails if file missing
load_env() {
  local env_file="$1"
  if [[ ! -f "$env_file" ]]; then
    log_error "Missing $env_file. Copy .env.example to .env and fill in MYSQL_ADMIN_USER / MYSQL_ADMIN_PASSWORD."
    return 1
  fi
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
}

# print_help — usage message
print_help() {
  cat >&2 <<'EOF'
Usage: wp-bootstrap [OPTIONS]

Inputs (any missing value will be prompted):
  --name <name>              Project name (slug)
  --gitlab-url <url>         GitLab repo URL
  --remote-domain <domain>   Remote staging domain
  --ssh-user <user>          SSH user for RunCloud
  --ssh-host <ip>            RunCloud server IP
  --rc-app-name <name>       RunCloud app name
  --db-name <name>           Local DB name
  --db-user <user>           Local DB user
  --db-password <pass>       Local DB password (prefer prompt over flag)
  --table-prefix <prefix>    WP table prefix (e.g. wp_)
  --local-domain <domain>    Local domain (default: <name no dashes>.stage)
  --theme-name <name>        Astra child theme dir name (default: <project name>)

Behavior:
  --from-file <path>         Load all inputs from YAML
  --resume                   Resume from .bootstrap-state in cwd or --name dir
  --force                    Overwrite all steps (asks confirmation)
  --force-step <NN>          Force a single step (e.g. 04)
  --skip-pull                Skip step 12 (first db pull)
  --dry-run                  Show commands without executing
  --yes                      Skip confirmations
  --help                     Show this help

See docs/specs/2026-05-20-wp-bootstrap-design.md for full design.
EOF
}

# YAML keys persisted in .bootstrap.yml (in order)
_YML_KEYS=(
  name gitlab_url remote_domain ssh_user ssh_host rc_app_name
  db_name db_user db_password table_prefix local_domain theme_name skip_pull
)

# Map YAML key → shell variable name (uppercase)
_yml_var() { tr '[:lower:]' '[:upper:]' <<<"$1"; }

# YAML escape: single-quote the value, doubling internal single quotes
_yml_escape() {
  local v="$1"
  v="${v//\'/\'\'}"
  printf "'%s'" "$v"
}

# save_bootstrap_yml <project-dir>
# No-op when DRY_RUN=true or when target dir doesn't exist yet.
save_bootstrap_yml() {
  [[ "${DRY_RUN:-false}" == "true" ]] && return 0
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local f="$dir/.bootstrap.yml"
  {
    printf '# wp-bootstrap configuration for %s\n' "$NAME"
    printf '# Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    local k var val
    for k in "${_YML_KEYS[@]}"; do
      var="$(_yml_var "$k")"
      val="${!var:-}"
      printf '%s: %s\n' "$k" "$(_yml_escape "$val")"
    done
  } > "$f"
}

# load_bootstrap_yml <path-to-yml>
# Parses our own constrained YAML (key: 'value' on one line each).
load_bootstrap_yml() {
  local f="$1"
  [[ -f "$f" ]] || { log_error "Missing $f"; return 1; }
  local line key val var
  while IFS= read -r line; do
    # Skip comments and blanks
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    # Match: key: 'value'
    if [[ "$line" =~ ^([a-z_]+):[[:space:]]*\'(.*)\'$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      # Unescape doubled single quotes
      val="${val//\'\'/\'}"
      var="$(_yml_var "$key")"
      printf -v "$var" '%s' "$val"
    fi
  done < "$f"
}

# Derive default local domain from name: remove dashes, append .stage
_derive_local_domain() {
  local name="$1"
  printf '%s.stage' "${name//-/}"
}

# Prompt for any missing input. Reads from stdin interactively.
# Order is fixed; default suggestions where convention applies.
prompt_missing_inputs() {
  [[ -z "$NAME" ]]             && prompt_with_default "Project name (slug)"                      NAME
  [[ -z "$GITLAB_URL" ]]       && prompt_with_default "GitLab repo URL"                          GITLAB_URL
  [[ -z "$REMOTE_DOMAIN" ]]    && prompt_with_default "Remote staging domain"                    REMOTE_DOMAIN
  [[ -z "$SSH_USER" ]]         && prompt_with_default "SSH user (RunCloud)"                      SSH_USER
  [[ -z "$SSH_HOST" ]]         && prompt_with_default "SSH host / IP (RunCloud)"                 SSH_HOST
  [[ -z "$RC_APP_NAME" ]]      && prompt_with_default "RunCloud app name"                        RC_APP_NAME
  [[ -z "$DB_NAME" ]]          && prompt_with_default "Local DB name"                            DB_NAME
  [[ -z "$DB_USER" ]]          && prompt_with_default "Local DB user"                            DB_USER
  [[ -z "$DB_PASSWORD" ]]      && prompt_password    "Local DB password"                         DB_PASSWORD
  [[ -z "$TABLE_PREFIX" ]]     && prompt_with_default "WP table prefix (e.g. wp_)"               TABLE_PREFIX
  if [[ -z "$LOCAL_DOMAIN" ]]; then
    local suggested
    suggested="$(_derive_local_domain "$NAME")"
    prompt_with_default "Local domain" LOCAL_DOMAIN "$suggested"
  fi
  if [[ -z "$THEME_NAME" ]]; then
    prompt_with_default "Astra child theme name" THEME_NAME "$NAME"
  fi
}

# Print recap of all resolved values (DB_PASSWORD masked) and ask for confirmation.
recap_and_confirm() {
  local masked="${DB_PASSWORD:+********}"
  cat >&2 <<EOF

============================================================
wp-bootstrap — Recap
============================================================
  name                  : $NAME
  gitlab_url            : $GITLAB_URL
  remote_domain         : $REMOTE_DOMAIN
  ssh_user              : $SSH_USER
  ssh_host              : $SSH_HOST
  rc_app_name           : $RC_APP_NAME
  db_name               : $DB_NAME
  db_user               : $DB_USER
  db_password           : $masked
  table_prefix          : $TABLE_PREFIX
  local_domain          : $LOCAL_DOMAIN
  theme_name            : $THEME_NAME
  skip_pull             : $SKIP_PULL
  resume                : $RESUME
  force                 : $FORCE
  force_step            : ${FORCE_STEP:-(none)}
  dry_run               : $DRY_RUN
============================================================
EOF
  if [[ "$YES" == "true" ]]; then
    log_info "Skipping confirmation (--yes)"
    return 0
  fi
  confirm "Proceed?" "Y"
}

# resolve_inputs — applies the priority order:
# 1. flags already in vars (from parse_flags)
# 2. --from-file content
# 3. .bootstrap.yml in target dir (only if --resume)
# 4. interactive prompts
# 5. .env defaults (already in env via load_env)
resolve_inputs() {
  # Step 2: --from-file
  if [[ -n "$FROM_FILE" ]]; then
    log_info "Loading inputs from $FROM_FILE"
    load_bootstrap_yml "$FROM_FILE" || return 1
  fi

  # Step 3: --resume: find .bootstrap.yml
  if [[ "$RESUME" == "true" ]]; then
    local resume_yml=""
    if [[ -n "$NAME" && -f "$DEFAULT_SITES_DIR/$NAME/.bootstrap.yml" ]]; then
      resume_yml="$DEFAULT_SITES_DIR/$NAME/.bootstrap.yml"
    elif [[ -f "$PWD/.bootstrap.yml" ]]; then
      resume_yml="$PWD/.bootstrap.yml"
    else
      log_error "--resume: cannot find .bootstrap.yml in cwd or in DEFAULT_SITES_DIR/\$NAME. Provide --name."
      return 1
    fi
    log_info "Resuming from $resume_yml"
    load_bootstrap_yml "$resume_yml" || return 1
  fi

  # Step 4: prompt for any missing input
  prompt_missing_inputs

  # Validate mandatory fields
  local missing=()
  [[ -z "$NAME" ]]             && missing+=("name")
  [[ -z "$GITLAB_URL" ]]       && missing+=("gitlab_url")
  [[ -z "$REMOTE_DOMAIN" ]]    && missing+=("remote_domain")
  [[ -z "$SSH_USER" ]]         && missing+=("ssh_user")
  [[ -z "$SSH_HOST" ]]         && missing+=("ssh_host")
  [[ -z "$RC_APP_NAME" ]]      && missing+=("rc_app_name")
  [[ -z "$DB_NAME" ]]          && missing+=("db_name")
  [[ -z "$DB_USER" ]]          && missing+=("db_user")
  [[ -z "$DB_PASSWORD" ]]      && missing+=("db_password")
  [[ -z "$TABLE_PREFIX" ]]     && missing+=("table_prefix")
  [[ -z "$LOCAL_DOMAIN" ]]     && missing+=("local_domain")
  [[ -z "$THEME_NAME" ]]       && missing+=("theme_name")
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required inputs: ${missing[*]}"
    return 1
  fi

  # Final recap
  recap_and_confirm
}
