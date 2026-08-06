#!/usr/bin/env bash
# lib/prereqs.sh — verify required tools are installed

# Format: "cmd|install hint"
_REQUIRED_TOOLS=(
  "brew|install from https://brew.sh"
  "git|brew install git"
  "wp|brew install wp-cli"
  "mysql|brew install mysql-client (and add to PATH)"
  "node|brew install nvm && nvm install 20.19"
  "npm|comes with node"
  "rsync|installed by default on macOS"
  "curl|installed by default on macOS"
  "ssh|installed by default on macOS"
  "scp|installed by default on macOS"
  "awk|installed by default on macOS"
)

# check_bash_version — wp-bootstrap requires bash 4+ (associative arrays, printf -v).
# macOS ships bash 3.2; user must brew install bash and ensure /opt/homebrew/bin is ahead in PATH.
check_bash_version() {
  if (( BASH_VERSINFO[0] < 4 )); then
    log_error "wp-bootstrap requires Bash 4.0+ (you're on $BASH_VERSION)."
    log_error "  Fix on macOS: brew install bash"
    log_error "  Then ensure '/opt/homebrew/bin/bash' is on PATH before '/bin/bash'."
    return 1
  fi
  return 0
}

# check_prereqs — returns 0 if all present, 1 otherwise. Prints missing tools with hints.
check_prereqs() {
  check_bash_version || return 1

  local missing=()
  local entry cmd hint
  for entry in "${_REQUIRED_TOOLS[@]}"; do
    cmd="${entry%%|*}"
    hint="${entry##*|}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("  - $cmd → $hint")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required tools:"
    printf '%s\n' "${missing[@]}" >&2
    return 1
  fi
  return 0
}
