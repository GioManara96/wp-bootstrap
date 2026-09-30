# wpb (wp-bootstrap)

One command to get a WordPress project running locally, with no questions in the common path:

- `wpb new <empty-gitlab-repo>` — new project from a starter, pushed to GitLab
- `wpb get <gitlab-repo>` — existing project: clone, core, DB, `wp-config`, plugin files, first DB pull

Stack: macOS 12.3+ (needs `readlink -f`), Homebrew Apache (`httpd`) + MariaDB/MySQL, WP-CLI, dnsmasq wildcard for `.stage`,
RunCloud-hosted staging (SSH).

## Install

```bash
brew install bash wp-cli httpd mysql-client dnsmasq nvm
git clone <this repo> ~/path/to/wp-bootstrap
echo 'alias wpb="/opt/homebrew/bin/bash ~/path/to/wp-bootstrap/wpb"' >> ~/.zshrc && source ~/.zshrc
```

Use `/opt/homebrew/bin/bash` on Apple Silicon (`/usr/local/bin/bash` on Intel), or symlink `wpb`
into your `PATH` instead of the alias.

```bash
wpb setup
```

`wpb setup` (idempotent) writes `~/.config/wpb/config` (mode 600), checks MySQL and dnsmasq, and
appends **one** wildcard vhost to the Apache vhosts file (backup + `httpd -t` before restart):
every `~/Sites/<folder>` is served at `http://<folder>.stage`. No per-project vhost, no sudo.
Existing per-site vhost blocks keep working (they match first). `wpb setup` resolves Homebrew's
`httpd` (not `/usr/sbin/httpd`) for config checks and restarts.

A **starter** (theme, plugins, frontend tools) is optional and lives in a separate private repo;
`wpb setup` asks for its path. Without it, everything except `new` and `starter:refresh` works.

## Commands

| Command | What it does |
|---|---|
| `wpb setup` | config, MySQL check, dnsmasq check, wildcard vhost |
| `wpb new <url>` | copy starter → rename child theme → core → DB → wp-config → install + activate → push |
| `wpb get <url>` | clone → `.env` (asks only missing remote values) → core → DB → wp-config → `plugins:pull` → `db:pull` |
| `wpb db:pull` / `db:push` | sync the DB with the remote (`db:push` asks for confirmation) |
| `wpb plugins:pull` | rsync remote `wp-content/plugins` (`--ignore-existing`); run by `get`. Some plugin folders (e.g. `dist/`) may be git-ignored in project repos |
| `wpb assets:pull` / `assets:push` | rsync `wp-content/uploads` (`--ignore-existing`) |
| `wpb ssh` | shell in the remote app folder |
| `wpb starter:refresh` | copy the newest plugin/theme versions found in `~/Sites` into the starter |

Options: `--name <name>`, `--no-pull`, `--force-step <id>`, `--dry-run`, `--yes`.

## Naming

Folder = domain: `~/Sites/<name>` → `http://<name>.stage`. `<name>` comes from the repo URL
(`…/acme-hotel.git` → `acme-hotel`) unless `--name` is given. Local DB: `<name>_db`,
user `<name>_user` (dashes → underscores), password from config (default `password`).

## Project `.env`

Remote data lives in `<project>/.env`, never committed (added to `.git/info/exclude`,
denied by Apache):

```
REMOTE_SSH_USER=
REMOTE_SSH_HOST=
REMOTE_APP_NAME=
REMOTE_URL=
LOCAL_URL=
```

All remote commands (`db:*`, `plugins:pull`, `assets:*`, `ssh`) connect as `REMOTE_SSH_USER@REMOTE_SSH_HOST` taken from this `.env`; the old
`rc-<user>` SSH alias is no longer used. If your SSH key or port was configured on that alias, add a
matching `Host` entry for the server's IP in `~/.ssh/config`.

Projects created before wpb: running any remote command imports the values from an existing
`sync-operation.sh` / `db-operation.sh`.

## Resume

Progress is stored in `<project>/.bootstrap-state`. If a step fails, fix the cause and re-run the
same command: finished steps are skipped. Re-run a single step with `--force-step <id>`
(`core_download`, `db_create`, `wp_config`, `htaccess`, `wp_install`, `first_pull`, …).
wpb never drops a database.

## Tests

```bash
bash tests/run-all.sh
```
