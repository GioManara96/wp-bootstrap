#!/usr/bin/env bash
# lib/steps/09-vhost.sh

# _vhost_block_exists <vhost-file> <project-name>
_vhost_block_exists() {
  local file="$1" name="$2"
  [[ -f "$file" ]] || return 1
  grep -q "^# >>> wp-bootstrap: ${name} >>>$" "$file"
}

# _remove_existing_block <vhost-file> <project-name>
# Strips the block between the two marker lines (inclusive). Requires sudo.
_remove_existing_block() {
  local file="$1" name="$2"
  local start_marker="# >>> wp-bootstrap: ${name} >>>"
  local end_marker="# <<< wp-bootstrap: ${name} <<<"
  local tmp
  tmp="$(mktemp)"
  sudo awk -v s="$start_marker" -v e="$end_marker" '
    BEGIN { skip=0 }
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    skip==0 { print }
  ' "$file" > "$tmp"
  sudo cp "$tmp" "$file"
  rm -f "$tmp"
}

step_09_vhost() {
  local id="09_vhost"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local vhost_file="$DEFAULT_APACHE_VHOST_FILE"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "09" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 09 "vhost … SKIP (already done)"
    return 0
  fi

  if _vhost_block_exists "$vhost_file" "$NAME"; then
    if [[ "$force_this" == "true" ]]; then
      log_warn "Removing existing vhost block for $NAME (--force, requires sudo)"
      [[ "$DRY_RUN" == "true" ]] || _remove_existing_block "$vhost_file" "$NAME"
    else
      log_error "vhost block for '$NAME' already exists in $vhost_file. Use --force, --force-step 09, or --resume."
      return 1
    fi
  fi

  log_step 09 "vhost: appending block to $vhost_file (requires sudo)"

  local today
  today="$(date '+%d/%m/%Y')"
  local tmp_block
  tmp_block="$(mktemp)"
  substitute_template "$SCRIPT_ROOT/templates/vhost.template.conf" "$tmp_block" \
    PROJECT_NAME    "$NAME" \
    TODAY_DATE      "$today" \
    VHOST_EMAIL     "$DEFAULT_VHOST_EMAIL" \
    DOCUMENT_ROOT   "$project_dir" \
    LOCAL_DOMAIN    "$LOCAL_DOMAIN" \
    ERROR_LOG_PATH  "$DEFAULT_SITES_DIR/logs/${NAME}-wp-error.log" \
    ACCESS_LOG_PATH "$DEFAULT_SITES_DIR/logs/${NAME}-wp-access.log"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: sudo tee -a $vhost_file (block content):"
    cat "$tmp_block" >&2
    rm -f "$tmp_block"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  # Append a blank line then the block
  printf '\n' | sudo tee -a "$vhost_file" >/dev/null
  sudo tee -a "$vhost_file" < "$tmp_block" >/dev/null

  rm -f "$tmp_block"

  state_mark_done "$project_dir" "$id"
}
