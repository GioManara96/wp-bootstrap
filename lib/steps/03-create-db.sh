#!/usr/bin/env bash
# lib/steps/03-create-db.sh

# Wrapper to run mysql as admin (uses MYSQL_ADMIN_USER + MYSQL_ADMIN_PASSWORD from .env).
_mysql_admin() {
  MYSQL_PWD="$MYSQL_ADMIN_PASSWORD" mysql -u "$MYSQL_ADMIN_USER" -h localhost "$@"
}

_db_exists() {
  local name="$1"
  _mysql_admin -N -e "SHOW DATABASES LIKE '${name//\'/\\\'}'" | grep -q "^${name}$"
}

step_03_create_db() {
  local id="03_create_db"
  local project_dir="$DEFAULT_SITES_DIR/$NAME"
  local force_this=false
  [[ "$FORCE" == "true" || "$FORCE_STEP" == "03" ]] && force_this=true

  if state_is_done "$project_dir" "$id" && [[ "$force_this" != "true" ]]; then
    log_step 03 "create-db … SKIP (already done)"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_step 03 "create-db (DRY-RUN)"
    log_info "DRY-RUN: CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' …; GRANT ALL …"
    state_mark_done "$project_dir" "$id"
    return 0
  fi

  if _db_exists "$DB_NAME"; then
    if [[ "$force_this" == "true" ]]; then
      log_warn "Dropping existing database $DB_NAME and user $DB_USER (--force)"
      _mysql_admin -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; DROP USER IF EXISTS '$DB_USER'@'localhost';" || return 1
    else
      log_error "Database $DB_NAME already exists. Use --force, --force-step 03, or --resume."
      return 1
    fi
  fi

  log_step 03 "create-db: $DB_NAME, user $DB_USER"
  local sql
  sql="CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  sql+="CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
  sql+="GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
  sql+="FLUSH PRIVILEGES;"
  _mysql_admin -e "$sql" || return 1

  state_mark_done "$project_dir" "$id"
}
