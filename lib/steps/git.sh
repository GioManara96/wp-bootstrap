#!/usr/bin/env bash
# lib/steps/git.sh — clone (get), init/push (new, adopt), .gitignore (adopt), local excludes (all).

step_clone() {
  step_begin clone "git clone $GIT_URL" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: git clone $GIT_URL $PROJECT_DIR"; return 0; fi
  git clone "$GIT_URL" "$PROJECT_DIR" || return 1
  state_init "$PROJECT_DIR"
  step_done clone
}

# step_git_init — git init + origin; with an empty GIT_URL (wpb adopt without a repo) local only
step_git_init() {
  step_begin git_init "git init${GIT_URL:+ + origin $GIT_URL}" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: git init -b main${GIT_URL:+; git remote add origin $GIT_URL}"; return 0; fi
  [[ -d "$PROJECT_DIR/.git" ]] || in_project git init -q -b main || return 1
  [[ -n "$GIT_URL" ]] || { step_done git_init; return 0; }
  local cur
  if cur="$(in_project git remote get-url origin 2>/dev/null)"; then
    if [[ "$cur" != "$GIT_URL" ]]; then
      log_error "git_init: origin is already $cur (expected $GIT_URL)"
      return 1
    fi
  else
    in_project git remote add origin "$GIT_URL" || return 1
  fi
  step_done git_init
}

# git_exclude_local <dir> — keep local-only files out of git without touching .gitignore
git_exclude_local() {
  local dir="$1" f entry
  [[ -d "$dir/.git" ]] || return 0
  f="$dir/.git/info/exclude"
  mkdir -p "$dir/.git/info" && touch "$f" || return 1
  for entry in .env .bootstrap-state tmp/ node_modules/ wp-config.php.tmp; do
    grep -qxF "$entry" "$f" || printf '%s\n' "$entry" >> "$f"
  done
}

step_git_exclude() {
  step_begin git_exclude "exclude .env, .bootstrap-state, tmp/ from git" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: append to .git/info/exclude"; return 0; fi
  git_exclude_local "$PROJECT_DIR" || return 1
  step_done git_exclude
}

# step_gitignore — the standard WordPress .gitignore, unless the project already has one
step_gitignore() {
  step_begin gitignore ".gitignore" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: copy gitignore.template if absent"; return 0; fi
  if [[ -f "$PROJECT_DIR/.gitignore" ]]; then
    log_info "gitignore: keeping existing file"
  else
    cp "$WPB_ROOT/templates/gitignore.template" "$PROJECT_DIR/.gitignore" || return 1
  fi
  step_done gitignore
}

step_first_push() {
  step_begin first_push "initial commit + push" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: git add -A; git commit; git push -u origin main"; return 0; fi
  in_project git add -A || return 1
  local leaked
  leaked="$(in_project git ls-files --cached wp-config.php .env)" || return 1
  if [[ -n "$leaked" ]]; then
    log_error "Refusing to push: secrets are tracked by git ($(tr '\n' ' ' <<<"$leaked")). Add them to .gitignore, remove them from the index (git rm --cached), then re-run."
    return 1
  fi
  if ! in_project git rev-parse --verify -q HEAD >/dev/null; then
    in_project git commit -q -m "${FIRST_COMMIT_MSG:-Initial commit from wpb starter}" || return 1
  fi
  in_project git push -u origin main || return 1
  step_done first_push
}
