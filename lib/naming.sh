#!/usr/bin/env bash
# lib/naming.sh — derive project name, DB identifiers and URLs. Pure functions.

# name_from_git_url <url> — last path segment without ".git"
#   git@host:group/sample-site.git → sample-site ; https://host/g/sub/foo/ → foo
name_from_git_url() {
  local u="${1%/}"
  u="${u%.git}"
  u="${u##*/}"
  u="${u##*:}"
  printf '%s' "$u"
}

# db_slug <name> — lowercase, non [a-z0-9_] → "_", max 27 chars so that
# "<slug>_user" fits MySQL's 32-char user name limit.
db_slug() {
  local s
  s="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
  s="${s//[^a-z0-9_]/_}"
  printf '%s' "${s:0:27}"
}

db_name_for() { printf '%s_db'   "$(db_slug "$1")"; }
db_user_for() { printf '%s_user' "$(db_slug "$1")"; }

# local_url_for <name> — http://<name>.<LOCAL_TLD>
local_url_for() { printf 'http://%s.%s' "$1" "${LOCAL_TLD:-stage}"; }

# valid_project_name <name> — folder name must be a DNS label (wildcard vhost)
valid_project_name() { (( ${#1} <= 63 )) && [[ "$1" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; }

# url_strip_slash <url> — remove trailing slashes
url_strip_slash() {
  local u="$1"
  while [[ "$u" == */ ]]; do u="${u%/}"; done
  printf '%s' "$u"
}
