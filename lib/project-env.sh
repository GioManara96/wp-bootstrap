#!/usr/bin/env bash
# lib/project-env.sh — per-project .env (git-ignored) holding the remote RunCloud data.
# Requires lib/utils.sh (prompt_with_default, kv_clean_value, log_*) and lib/naming.sh (url_strip_slash).

PENV_KEYS=(REMOTE_SSH_USER REMOTE_SSH_HOST REMOTE_APP_NAME REMOTE_URL LOCAL_URL)
PENV_REMOTE_KEYS=(REMOTE_SSH_USER REMOTE_SSH_HOST REMOTE_APP_NAME REMOTE_URL)

declare -gA _PENV_PROMPTS=(
  [REMOTE_SSH_USER]="RunCloud SSH user"
  [REMOTE_SSH_HOST]="RunCloud server IP/host"
  [REMOTE_APP_NAME]="RunCloud web app name"
  [REMOTE_URL]="Remote URL (e.g. https://staging.example.com)"
  [LOCAL_URL]="Local URL"
)

# penv_get <file> <key> — value or empty
penv_get() {
  local line
  [[ -f "$1" ]] || return 0
  line="$(grep -m1 -E "^(export[[:space:]]+)?${2}=" "$1" || true)"
  [[ -n "$line" ]] || return 0
  kv_clean_value "${line#*=}"
}

# penv_set <file> <key> <value> — replace in place or append; *_URL values lose trailing slashes
penv_set() {
  local f="$1" key="$2" val="$3"
  [[ "$key" == *_URL ]] && val="$(url_strip_slash "$val")"
  touch "$f" || return 1
  if grep -qE "^(export[[:space:]]+)?${key}=" "$f"; then
    K="$key" V="$val" awk '$0 ~ ("^(export[ \t]+)?" ENVIRON["K"] "=") { print ENVIRON["K"] "=" ENVIRON["V"]; next } { print }' \
      "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
  else
    [[ -s "$f" && -n "$(tail -c1 "$f")" ]] && printf '\n' >> "$f"
    printf '%s=%s\n' "$key" "$val" >> "$f"
  fi
}

# penv_load <file> — PENV_KEYS into shell variables
penv_load() {
  local k
  for k in "${PENV_KEYS[@]}"; do printf -v "$k" '%s' "$(penv_get "$1" "$k")"; done
}

# penv_missing <file> <keys...> — keys with no value, one per line
penv_missing() {
  local f="$1" k
  shift
  for k in "$@"; do [[ -n "$(penv_get "$f" "$k")" ]] || printf '%s\n' "$k"; done
}

# penv_ensure <file> <keys...> — prompt (stdin) only for missing keys and save each answer
penv_ensure() {
  local f="$1" k val
  shift
  local -a missing
  mapfile -t missing < <(penv_missing "$f" "$@")
  for k in "${missing[@]}"; do
    [[ -z "$k" ]] && continue
    prompt_with_default "${_PENV_PROMPTS[$k]:-$k}" val
    [[ -n "$val" ]] || { log_error "$k is required"; return 1; }
    penv_set "$f" "$k" "$val"
  done
}

# penv_import_legacy <sync-operation.sh|db-operation.sh> <env-file>
penv_import_legacy() {
  local src="$1" f="$2" legacy val
  [[ -f "$src" ]] || return 1
  local -A map=(
    [RC_USER]=REMOTE_SSH_USER [RC_SERVERNAME]=REMOTE_SSH_HOST [RC_APP_NAME]=REMOTE_APP_NAME
    [W_URL_REMOTE]=REMOTE_URL [W_URL_LOCAL]=LOCAL_URL
  )
  for legacy in "${!map[@]}"; do
    val="$(grep -m1 -E "^${legacy}=" "$src" | cut -d= -f2- | sed -E 's/[[:space:]]+#.*$//')"
    [[ "$val" == *'$'* ]] && continue
    val="$(tr -d "\"'[:space:]" <<<"$val")"
    [[ -n "$val" ]] && penv_set "$f" "${map[$legacy]}" "$val"
  done
  return 0
}
