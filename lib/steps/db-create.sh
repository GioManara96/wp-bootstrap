#!/usr/bin/env bash
# lib/steps/db-create.sh — local DB + user. Never drops anything.

step_db_create() {
  step_begin db_create "database $DB_NAME / user $DB_USER" || return 0
  if [[ "$DRY_RUN" == "true" ]]; then log_info "DRY-RUN: CREATE DATABASE $DB_NAME; CREATE USER $DB_USER; GRANT"; return 0; fi
  local rc=0
  db_exists "$DB_NAME" || rc=$?
  case "$rc" in
    0) log_error "Database $DB_NAME already exists. wpb never drops data: drop it yourself or use --name."
       return 1 ;;
    1) ;;
    *) log_error "Cannot connect to MySQL as $MYSQL_ADMIN_USER — check 'wpb setup'"
       return 1 ;;
  esac
  # (a) user + grants, (b) verify credentials, (c) database last — a failed (b) stays resumable
  local sql
  sql="CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
  sql+="GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
  sql+="FLUSH PRIVILEGES;"
  mysql_admin -e "$sql" || return 1
  if ! MYSQL_PWD="$DB_PASSWORD" mysql -u "$DB_USER" -h localhost -e 'SELECT 1' >/dev/null; then
    log_error "User $DB_USER exists with a different password — fix it or change LOCAL_DB_PASSWORD"
    return 1
  fi
  mysql_admin -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || return 1
  step_done db_create
}
