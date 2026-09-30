#!/usr/bin/env bash
# lib/config.sh — user-level config (KEY="value" lines, mode 600). Local only, never committed.
# Requires lib/utils.sh (kv_clean_value, log_*).

: "${WPB_CONFIG_FILE:=$HOME/.config/wpb/config}"

_CONFIG_KEYS=(SITES_DIR MYSQL_ADMIN_USER MYSQL_ADMIN_PASSWORD LOCAL_DB_PASSWORD STARTER_REPO WP_LOCALE WP_MEMORY_LIMIT LOCAL_TLD VHOST_FILE)

config_defaults() {
  : "${SITES_DIR:=$HOME/Sites}"
  : "${MYSQL_ADMIN_USER:=root}"
  : "${MYSQL_ADMIN_PASSWORD:=}"
  : "${LOCAL_DB_PASSWORD:=password}"
  : "${STARTER_REPO:=}"
  : "${WP_LOCALE:=it_IT}"
  : "${WP_MEMORY_LIMIT:=768M}"
  : "${LOCAL_TLD:=stage}"
  : "${VHOST_FILE:=}"
}

_config_is_key() {
  local k
  for k in "${_CONFIG_KEYS[@]}"; do [[ "$k" == "$1" ]] && return 0; done
  return 1
}

# config_load — parse known keys from WPB_CONFIG_FILE (never sourced), then defaults.
config_load() {
  if [[ -f "$WPB_CONFIG_FILE" ]]; then
    local line key
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || continue
      key="${BASH_REMATCH[1]}"
      _config_is_key "$key" || continue
      printf -v "$key" '%s' "$(kv_clean_value "${BASH_REMATCH[2]}")"
    done < "$WPB_CONFIG_FILE"
  fi
  config_defaults
}

# config_save — write every known key from the current shell, mode 600.
config_save() {
  mkdir -p "$(dirname "$WPB_CONFIG_FILE")" || return 1
  local k
  ( umask 077
    {
      printf '# wpb config — local only, never commit\n'
      for k in "${_CONFIG_KEYS[@]}"; do printf '%s="%s"\n' "$k" "${!k:-}"; done
    } > "$WPB_CONFIG_FILE.tmp" && mv "$WPB_CONFIG_FILE.tmp" "$WPB_CONFIG_FILE" ) || return 1
  chmod 600 "$WPB_CONFIG_FILE"
}

# config_require — fail with a hint when `wpb setup` was never run.
config_require() {
  [[ -f "$WPB_CONFIG_FILE" ]] && return 0
  log_error "No config at $WPB_CONFIG_FILE — run 'wpb setup' first."
  return 1
}
