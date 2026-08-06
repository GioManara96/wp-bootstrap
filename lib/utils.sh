#!/usr/bin/env bash
# lib/utils.sh — logging, prompts, template substitution

# ---- color codes ----
_RESET=$'\033[0m'
_BLUE=$'\033[34m'
_GREEN=$'\033[32m'
_YELLOW=$'\033[33m'
_RED=$'\033[31m'
_GRAY=$'\033[90m'

_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_info()    { printf '%s[%s] [INFO]%s %s\n'    "$_BLUE"   "$(_timestamp)" "$_RESET" "$*" >&2; }
log_success() { printf '%s[%s] [ OK ]%s %s\n'    "$_GREEN"  "$(_timestamp)" "$_RESET" "$*" >&2; }
log_warn()    { printf '%s[%s] [WARN]%s %s\n'    "$_YELLOW" "$(_timestamp)" "$_RESET" "$*" >&2; }
log_error()   { printf '%s[%s] [FAIL]%s %s\n'    "$_RED"    "$(_timestamp)" "$_RESET" "$*" >&2; }
# Total steps in the bootstrap flow. Set by orchestrator before calling log_step.
: "${BOOTSTRAP_TOTAL_STEPS:=15}"

log_step()    { printf '%s[%s] [%s/%s] %s%s\n'   "$_GRAY"   "$(_timestamp)" "$1" "$BOOTSTRAP_TOTAL_STEPS" "$2" "$_RESET" >&2; }

# ---- prompt_with_default <message> <varname> [default] ----
# Reads a line from stdin into varname. If user hits Enter and default is set, uses default.
prompt_with_default() {
  local msg="$1" varname="$2" default="${3:-}"
  local input
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$msg" "$default" >&2
  else
    printf '%s: ' "$msg" >&2
  fi
  IFS= read -r input
  if [[ -z "$input" && -n "$default" ]]; then
    input="$default"
  fi
  printf -v "$varname" '%s' "$input"
}

# ---- prompt_password <message> <varname> ----
# Like prompt_with_default but silent input (no echo, no default).
prompt_password() {
  local msg="$1" varname="$2"
  local input
  printf '%s: ' "$msg" >&2
  IFS= read -r -s input
  printf '\n' >&2
  printf -v "$varname" '%s' "$input"
}

# ---- confirm <message> [default=N] ----
# Returns 0 on yes, 1 on no. Default is N unless argument is "y".
confirm() {
  local msg="$1" default="${2:-N}"
  local prompt input
  if [[ "$default" == "y" || "$default" == "Y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi
  printf '%s %s: ' "$msg" "$prompt" >&2
  IFS= read -r input
  input="${input:-$default}"
  [[ "$input" =~ ^[yY]$ ]]
}

# ---- substitute_template <template> <output> KEY1 val1 KEY2 val2 ... ----
# Copies template to output then sed-replaces each {{KEY}} with val.
# Uses awk for the substitution to support multi-line values and arbitrary special chars.
substitute_template() {
  local template="$1" output="$2"
  shift 2

  if (( ($# % 2) != 0 )); then
    log_error "substitute_template: KEY/VALUE args must be in pairs (got $# extra args after template/output)"
    return 1
  fi

  # Build associative array of replacements (bash 4+)
  declare -A repls
  while [[ $# -gt 0 ]]; do
    repls[$1]="$2"
    shift 2
  done

  # awk reads template, replaces {{KEY}} with values from environment.
  # We export each replacement as REPL_<key>, awk reads them by name.
  local awk_cmd='
    {
      out = ""
      rest = $0
      while (match(rest, /\{\{[A-Z_][A-Z0-9_]*\}\}/)) {
        key = substr(rest, RSTART+2, RLENGTH-4)
        env_name = "REPL_" key
        if (env_name in ENVIRON) {
          replacement = ENVIRON[env_name]
        } else {
          replacement = ""
        }
        out = out substr(rest, 1, RSTART-1) replacement
        rest = substr(rest, RSTART + RLENGTH)
      }
      print out rest
    }
  '

  # Export each replacement so awk sees it via ENVIRON.
  local key
  local -a env_args=()
  for key in "${!repls[@]}"; do
    env_args+=("REPL_${key}=${repls[$key]}")
  done

  env "${env_args[@]}" awk "$awk_cmd" "$template" > "$output"
}
