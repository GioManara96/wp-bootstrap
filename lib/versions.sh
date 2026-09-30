#!/usr/bin/env bash
# lib/versions.sh — read Version headers and compare versions.

_header_version() {
  grep -i -m1 '^[[:space:]/*#@]*Version:' "$1" \
    | sed -E 's/.*[Vv][Ee][Rr][Ss][Ii][Oo][Nn]:[[:space:]]*//; s#\*/.*$##' | tr -d '[:space:]'
}

# plugin_version <plugin-dir> — Version of the top-level PHP file declaring "Plugin Name:"
plugin_version() {
  local f
  for f in "$1"/*.php; do
    [[ -f "$f" ]] || continue
    if grep -qi -m1 '^[[:space:]/*#@]*Plugin Name:' "$f"; then
      _header_version "$f"
      return 0
    fi
  done
  return 1
}

# theme_version <theme-dir> — Version header of style.css
theme_version() {
  [[ -f "$1/style.css" ]] || return 1
  _header_version "$1/style.css"
}

# version_gt <a> <b> — true when a > b (natural version order)
version_gt() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" == "$1" ]]
}
