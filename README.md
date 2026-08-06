# wp-bootstrap

Bash automation that sets up a new WordPress staging-ready site locally in one command:
clone repo, download WP-IT, create local MySQL DB, generate wp-config / .htaccess / sync-operation.sh,
scaffold frontend_tools, append Apache vhost (sudo), restart Apache, optionally pull the remote DB.

Steps 1–2 (RunCloud app + GitLab repo creation) and step 13 (deploy webhook) remain manual —
they require browser interaction.

## Prerequisites

The following tools must be on `PATH`:

- `bash` 4+ — `brew install bash` on macOS (default 3.2 is too old; the script uses associative arrays and `printf -v`)
- `brew` — `https://brew.sh`
- `git`
- `wp` (WP-CLI) — `brew install wp-cli`
- `mysql` client — `brew install mysql-client` (add to PATH)
- `node` + `npm` — recommended via `brew install nvm` then `nvm install 20.19`
- `rsync`, `curl`, `ssh`, `scp`, `awk` (standard macOS)
- Apache via `brew install httpd` (configured for `.stage` resolution via dnsmasq or `/etc/hosts`)

A working SSH config to the RunCloud server is required for `sync-operation.sh` (rsync uses an
`rc-<ssh_user>` SSH alias for assets/themes/plugins).

## Setup (once)

```bash
cd /path/to/wp-bootstrap
cp .env.example .env
$EDITOR .env        # fill MYSQL_ADMIN_USER, MYSQL_ADMIN_PASSWORD
```

Add an alias to your shell:

```bash
echo 'alias wp-bootstrap="/opt/homebrew/bin/bash /path/to/wp-bootstrap/wp-bootstrap.sh"' >> ~/.zshrc
source ~/.zshrc
```

(Using the explicit `/opt/homebrew/bin/bash` ensures bash 4+ is used regardless of `PATH` ordering.)

## Usage

### Interactive (recommended)

```bash
wp-bootstrap
```

Answers each prompt; smart default suggested for `local_domain` (derived from `<name>` by removing
dashes and appending `.stage`).

### With flags

```bash
wp-bootstrap \
  --name <name> \
  --gitlab-url <gitlab-url> \
  --remote-domain <remote-domain> \
  --ssh-user <ssh-user> --ssh-host <ssh-host> \
  --rc-app-name <rc-app-name> \
  --db-name <db-name> --db-user <db-user> \
  --table-prefix <table-prefix>
# (will prompt only for db-password)
```

### From file

```bash
wp-bootstrap --from-file path/to/recipe.yml
```

Format matches the `.bootstrap.yml` saved automatically in each project.

### Resume after failure

If a step fails, fix the underlying issue then:

```bash
wp-bootstrap --resume                # reads .bootstrap.yml from cwd or --name dir
```

### Force a specific step

```bash
cd ~/Sites/<name>
wp-bootstrap --force-step 09         # e.g. re-apply vhost block after a manual edit
```

### Full overwrite (destructive)

```bash
wp-bootstrap --force --yes \
  --name ...                          # rm folder + DROP DB + replace vhost block
```

### Dry-run

```bash
wp-bootstrap --dry-run ...           # prints every command, makes no changes
```

## Steps performed

| # | Step | Notes |
|---|---|---|
| 01 | `git clone` GitLab repo → `~/Sites/<name>/` | strict: aborts if dir exists |
| 02 | `wp core download --locale=it_IT` | |
| 03 | `CREATE DATABASE` + `CREATE USER` + `GRANT ALL` | uses `.env` admin creds |
| 04 | Generate `wp-config.php` (live salts from api.wordpress.org) | |
| 04a | `wp core install` (admin/admin, idempotent) | needed so 04b/04c can activate |
| 04b | Delete default themes, install Astra, scaffold + activate child theme | child uses `--theme-name` value |
| 04c | Delete akismet + hello, install + activate 13 plugins | see plugin list below |
| 05 | Generate `.htaccess` | |
| 06 | `mkdir tmp/` | idempotent |
| 07 | Generate `sync-operation.sh` | parameterized from template |
| 08 | Copy `frontend_tools/` + `npm install` | `nvm use 20.19` if available |
| 09 | Append vhost block (marker comments) | requires sudo |
| 10 | `mkdir ~/Sites/logs/` | idempotent |
| 11 | `brew services restart httpd` | |
| – | Smoke test: `curl` + `wp db check` | warning, non-blocking |
| 12 | `./sync-operation.sh db:pull` | skipped with `--skip-pull` |

### Child theme (step 04b)

The child theme is scaffolded from `templates/child-theme/` (bundled starter template).
The directory is named after `--theme-name` (default: project name), and `style.css`
"Theme Name:" is set to the same value. Everything else (functions.php, inc/, languages/,
assets/) is copied verbatim — adjust per-project as needed.

### Plugins installed (step 04c)

Activated in order: elementor, better-wp-security, seo-by-rank-math, disable-comments,
contact-form-7, wpcf7-redirect, advanced-custom-fields, webp-express, wps-hide-login,
google-site-kit, indexnow, worker (ManageWP), wp-mail-smtp.

If a plugin fails to install (slug renamed, removed from .org), the step continues and
emits a warning; the rest still install. Re-run with `--force-step 04c` after fixing.

## Troubleshooting

**`MYSQL_ADMIN_PASSWORD` wrong** → step 03 fails. Edit `.env`, run `--resume`.

**`npm install` fails — Node version** → step 08 needs Node 20.19. Make sure `nvm` is installed
and `nvm install 20.19` has been run at least once.

**sudo prompt times out** → step 09 needs sudo. Stay near the terminal when running. If timed out,
`wp-bootstrap --resume`.

**vhost already has my block** → use `--force-step 09` to remove and re-append, or edit by hand
between the `# >>> wp-bootstrap: <name> >>>` markers.

**`db:pull` fails because remote is empty** → re-run with `--skip-pull`. When remote is ready,
`cd ~/Sites/<name> && ./sync-operation.sh db:pull` or `wp-bootstrap --resume --force-step 12`.

**Local domain not resolving** → check your dnsmasq config for `.stage` TLD or add an `/etc/hosts`
entry: `127.0.0.1 <name>.stage`.

**`declare: -A: invalid option`** → you're running with bash 3.2 (macOS default). Use
`/opt/homebrew/bin/bash` (install via `brew install bash`) and ensure your alias points to it.

## Files created per project

```
~/Sites/<name>/
├── .bootstrap.yml          # the "recipe" — keep for future reference
├── .bootstrap-state        # progress tracker
├── (WordPress files)
├── wp-config.php
├── .htaccess
├── tmp/
├── sync-operation.sh
└── frontend_tools/
```

## Development

Run tests:

```bash
/opt/homebrew/bin/bash tests/run-all.sh
```

- Implementation plan: `docs/plans/2026-05-20-wp-bootstrap-plan.md`
- Design spec: `docs/specs/2026-05-20-wp-bootstrap-design.md`

## Roadmap (deferred)

- Modernize `frontend_tools` (gulpfile + Node version)
- Neutral `assets/` scaffolding (replace project-specific starter assets with placeholders)
- Neutral `templates/child-theme/` content (works for new projects but still carries
  project-specific functions.php content and Italian text that should be genericized)
- Configurable plugin list (currently hard-coded in `lib/steps/04c-plugins.sh`)
- Optional skill wrapper for conversational driving via Claude Code
