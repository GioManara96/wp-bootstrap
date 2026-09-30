#!/usr/bin/env bash
# lib/steps/frontend-tools.sh — npm install in frontend_tools, in the background.

# _nvm_script — nvm.sh path (~/.nvm or Homebrew), empty if nvm is not installed
_nvm_script() {
  local p="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  if [[ -s "$p" ]]; then printf '%s' "$p"; return 0; fi
  p="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
  [[ -s "$p" ]] && printf '%s' "$p"
  return 0
}

step_frontend_tools() {
  local ft="$PROJECT_DIR/frontend_tools" log="$PROJECT_DIR/tmp/npm-install.log"
  step_begin frontend_tools "npm install in frontend_tools (background)" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: (cd frontend_tools && nvm install && npm install) &"; return 0; fi
  if [[ ! -f "$ft/package.json" ]]; then
    log_info "frontend_tools: no package.json, skipping"
    step_done frontend_tools
    return 0
  fi
  mkdir -p "$PROJECT_DIR/tmp" || return 1
  nohup /bin/bash -c '
    cd "$1" || exit 1
    if [ -n "$2" ]; then
      export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
      . "$2"
      if [ -f .nvmrc ]; then nvm install; else nvm install 20.19; fi || exit 1
    fi
    npm install
  ' _ "$ft" "$(_nvm_script)" > "$log" 2>&1 &
  log_info "frontend_tools: npm install running in background — log: $log"
  step_done frontend_tools
}
