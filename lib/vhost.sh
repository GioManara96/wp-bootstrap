#!/usr/bin/env bash
# lib/vhost.sh — locate the Apache vhosts file and append the wpb wildcard block once.

: "${HTTPD_BIN:=}"

# httpd_bin — Homebrew httpd (never /usr/sbin/httpd): $HTTPD_BIN, else $(brew --prefix)/bin/httpd
httpd_bin() {
  local b
  if [[ -n "$HTTPD_BIN" ]]; then printf '%s' "$HTTPD_BIN"; return 0; fi
  b="$(brew --prefix 2>/dev/null)/bin/httpd"
  [[ -x "$b" ]] || return 1
  printf '%s' "$b"
}

WPB_VHOST_BEGIN="# >>> wpb: wildcard >>>"

WPB_VHOST_END="# <<< wpb: wildcard <<<"

# vhost_include_from_conf <httpd.conf> — first active absolute "Include[Optional] …vhost…" path
vhost_include_from_conf() {
  local path
  path="$(grep -iE '^[[:space:]]*Include(Optional)?[[:space:]]+[^#]*vhost' "$1" | head -1 | awk '{print $2}')"
  path="${path%\"}"; path="${path#\"}"
  [[ -n "$path" && "$path" == /* ]] || return 1
  printf '%s' "$path"
}

# vhost_detect_file — VHOST_FILE from config, else the vhosts file included by httpd.conf
vhost_detect_file() {
  if [[ -n "${VHOST_FILE:-}" ]]; then
    printf '%s' "$VHOST_FILE"
    return 0
  fi
  local conf bin out
  bin="$(httpd_bin)" || return 1
  out="$("$bin" -V 2>/dev/null)" || true
  conf="$(sed -n 's/.*SERVER_CONFIG_FILE="\(.*\)"/\1/p' <<<"$out")"
  [[ -f "$conf" ]] || return 1
  vhost_include_from_conf "$conf"
}

vhost_has_wildcard() { grep -qF "$WPB_VHOST_BEGIN" "$1" && grep -qF "$WPB_VHOST_END" "$1"; }

# vhost_append_block <vhosts-file> <rendered-block-file> — no-op when already present
vhost_append_block() {
  vhost_has_wildcard "$1" && return 0
  { printf '\n'; cat "$2"; } >> "$1"
}
