#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/naming.sh"

fail() { echo "FAIL: $1"; exit 1; }

[[ "$(name_from_git_url git@git.example.com:group/sample-site.git)" == "sample-site" ]]      || fail "ssh url"
[[ "$(name_from_git_url https://git.example.com/group/sub/acme-hotel.git)" == "acme-hotel" ]] || fail "https url"
[[ "$(name_from_git_url https://git.example.com/group/foo/)" == "foo" ]]                  || fail "trailing slash, no .git"
[[ "$(name_from_git_url git@git.example.com:foo.git)" == "foo" ]]                         || fail "no group"

[[ "$(db_slug acme-hotel-north)" == "acme_hotel_north" ]] || fail "db_slug dashes"
[[ "$(db_slug Foo.Bar)" == "foo_bar" ]]                         || fail "db_slug case/dots"
[[ "$(db_name_for sample-site)" == "sample_site_db" ]]              || fail "db_name_for"
[[ "$(db_user_for sample-site)" == "sample_site_user" ]]            || fail "db_user_for"
u="$(db_user_for a-very-long-project-name-that-exceeds-mysql-limits)"
(( ${#u} <= 32 )) || fail "db user too long: $u (${#u})"

[[ "$(LOCAL_TLD=stage local_url_for foo-bar)" == "http://foo-bar.stage" ]] || fail "local_url_for"

valid_project_name foo-bar || fail "valid name rejected"
valid_project_name abc123  || fail "digits rejected"
valid_project_name Foo     && fail "uppercase accepted"
valid_project_name foo_bar && fail "underscore accepted"
valid_project_name -foo    && fail "leading dash accepted"

[[ "$(url_strip_slash https://x.example.com//)" == "https://x.example.com" ]] || fail "url_strip_slash"
[[ "$(url_strip_slash http://a.stage)" == "http://a.stage" ]]                 || fail "url_strip_slash noop"
[[ "$(url_other_scheme https://x.example.com)" == "http://x.example.com" ]]   || fail "url_other_scheme https"
[[ "$(url_other_scheme http://x.example.com/a)" == "https://x.example.com/a" ]] || fail "url_other_scheme http"
[[ "$(url_json_escape https://x.example.com/a)" == 'https:\/\/x.example.com\/a' ]] || fail "url_json_escape"
[[ "$(url_host https://x.example.com/a/b)" == "x.example.com" ]]             || fail "url_host"


# ---- valid_project_name length ----
n63="$(printf 'a%.0s' {1..63})"; n64="${n63}a"
valid_project_name "$n63" || fail "63 chars rejected"
valid_project_name "$n64" && fail "64 chars accepted"

echo "PASS: test_naming.sh"
