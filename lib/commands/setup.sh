#!/usr/bin/env bash
# lib/commands/setup.sh — one-time, idempotent machine setup.

# _setup_import_legacy_env <path> — MySQL admin creds from the old wp-bootstrap .env.
# Called on the first run only (no config yet); legacy values override the defaults.
_setup_import_legacy_env() {
  local f="$1" line
  [[ -f "$f" ]] || return 0
  line="$(grep -m1 '^MYSQL_ADMIN_USER=' "$f" || true)"
  [[ -n "$line" ]] && MYSQL_ADMIN_USER="$(kv_clean_value "${line#*=}")"
  line="$(grep -m1 '^MYSQL_ADMIN_PASSWORD=' "$f" || true)"
  [[ -n "$line" ]] && MYSQL_ADMIN_PASSWORD="$(kv_clean_value "${line#*=}")"
  return 0
}

# _setup_normalize_sites_dir <path> — expand leading ~, strip trailing /, require absolute
_setup_normalize_sites_dir() {
  local d="$1"
  [[ "$d" == "~" ]] && d="$HOME"
  [[ "$d" == "~/"* ]] && d="$HOME/${d#\~/}"
  while [[ "${#d}" -gt 1 && "$d" == */ ]]; do d="${d%/}"; done
  [[ "$d" == /* ]] || { log_error "Sites directory must be an absolute path (got '$1')"; return 1; }
  printf '%s' "$d"
}

_setup_check_dns() {
  local prefix
  prefix="$(brew --prefix)"
  if ! grep -rqsF -e "address=/.${LOCAL_TLD}/" -e "address=/${LOCAL_TLD}/" "$prefix/etc/dnsmasq.conf" "$prefix/etc/dnsmasq.d/"; then
    log_warn "dnsmasq has no wildcard for .$LOCAL_TLD — add 'address=/.$LOCAL_TLD/127.0.0.1'"
  fi
  [[ -f "/etc/resolver/$LOCAL_TLD" ]] || log_warn "/etc/resolver/$LOCAL_TLD missing — macOS won't ask dnsmasq for .$LOCAL_TLD"
}

_setup_wildcard_vhost() {
  local vfile block backup bin mods
  if ! vfile="$(vhost_detect_file)"; then
    log_error "Cannot detect the Apache vhosts file. Set VHOST_FILE=<path> in $WPB_CONFIG_FILE."
    return 1
  fi
  if vhost_has_wildcard "$vfile"; then
    log_info "Wildcard vhost already present in $vfile"
    if ! grep -qF "VirtualDocumentRoot \"$SITES_DIR/%-2\"" "$vfile"; then
      log_warn "The wildcard block in $vfile does not point to $SITES_DIR — SITES_DIR changed; update the block manually."
    fi
    log_info "If *.$LOCAL_TLD sites don't respond: brew services restart httpd"
    return 0
  fi
  bin="$(httpd_bin)" || { log_error "Homebrew httpd not found: brew install httpd"; return 1; }
  mods="$("$bin" -M 2>/dev/null)" || true
  if ! grep -q vhost_alias_module <<<"$mods"; then
    log_error "mod_vhost_alias is not loaded: uncomment 'LoadModule vhost_alias_module' in httpd.conf"
    return 1
  fi
  [[ -w "$vfile" ]] || { log_error "$vfile is not writable by $(whoami)"; return 1; }
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: append wildcard block to $vfile, httpd -t, restart"; return 0; fi

  block="$(mktemp)"
  substitute_template "$WPB_ROOT/templates/vhost-wildcard.template.conf" "$block" \
    SITES_DIR "$SITES_DIR" LOCAL_TLD "$LOCAL_TLD" || { rm -f "$block"; return 1; }
  backup="$vfile.bak-wpb-$(date +%Y%m%d%H%M%S)"
  cp -p "$vfile" "$backup" || { rm -f "$block"; return 1; }
  if ! vhost_append_block "$vfile" "$block"; then
    rm -f "$block"
    log_error "Could not append to $vfile — restoring from $backup"
    cp -p "$backup" "$vfile" || log_error "Restore failed: copy $backup over $vfile manually"
    return 1
  fi
  rm -f "$block"
  if ! "$bin" -t >/dev/null 2>&1; then
    "$bin" -t
    log_error "httpd -t failed — restoring $vfile from $backup"
    cp -p "$backup" "$vfile" || log_error "Restore failed: copy $backup over $vfile manually"
    return 1
  fi
  if ! brew services restart httpd >/dev/null; then
    log_error "Apache restart failed — run: brew services restart httpd"
    return 1
  fi
  log_success "Wildcard vhost added to $vfile (backup: $backup)"
}

cmd_setup() {
  check_prereqs || return 1
  [[ -f "$WPB_CONFIG_FILE" ]] || _setup_import_legacy_env "$WPB_ROOT/.env"
  local pw
  prompt_with_default "Sites directory" SITES_DIR "$SITES_DIR"
  SITES_DIR="$(_setup_normalize_sites_dir "$SITES_DIR")" || return 1
  prompt_with_default "MySQL admin user" MYSQL_ADMIN_USER "$MYSQL_ADMIN_USER"
  prompt_password "MySQL admin password (Enter = keep current)" pw
  [[ -n "$pw" ]] && MYSQL_ADMIN_PASSWORD="$pw"
  if ! mysql_admin -e "SELECT 1" >/dev/null; then
    log_error "Cannot connect to MySQL as $MYSQL_ADMIN_USER"
    log_error "On Homebrew MariaDB, root uses unix_socket auth by default: try your macOS username as admin user (e.g. $(whoami)) with an empty password, or set a root password."
    return 1
  fi
  prompt_with_default "Local DB password for projects" LOCAL_DB_PASSWORD "$LOCAL_DB_PASSWORD"
  if [[ "$LOCAL_DB_PASSWORD" == *"'"* || "$LOCAL_DB_PASSWORD" == *'\'* ]]; then
    log_error "The local DB password must not contain ' or \\ (it is written into wp-config.php)"
    return 1
  fi
  prompt_with_default "Internal starter repo path (Enter = none)" STARTER_REPO "$STARTER_REPO"
  if [[ -n "$STARTER_REPO" ]]; then starter_require || return 1; fi
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY-RUN: save config to $WPB_CONFIG_FILE; mkdir -p $SITES_DIR/logs"
  else
    config_save || return 1
    log_success "Config saved to $WPB_CONFIG_FILE (mode 600)"
    mkdir -p "$SITES_DIR/logs" || return 1
  fi
  _setup_check_dns
  _setup_wildcard_vhost || return 1
  log_success "Setup complete. Try: wpb get <gitlab-url>"
}
