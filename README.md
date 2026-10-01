# wpb (wp-bootstrap)

`wpb` gets a WordPress project running on your Mac with one command and no questions in the
common path.

- **New project:** `wpb new <empty-repo-url>`. It creates the site from a starter and pushes it
  to a new repository.
- **Existing project:** `wpb get <repo-url>`. It clones the repository, sets up WordPress and
  the database, then pulls the database and missing plugin files from the staging server.
- **Live site, not on git:** `wpb adopt [<empty-repo-url>]`. It takes themes, plugins and the
  database from the RunCloud server, and pushes them to a new repository if you give one.
- **Day to day:** `wpb db:pull`, `wpb db:push`, `wpb assets:pull` and the other sync commands,
  run from inside the project folder.

Every project folder `~/Sites/<name>` is served at `http://<name>.stage`. You never edit an
Apache vhost again.

---

## Contents

1. [Requirements](#requirements)
2. [One-time machine setup](#1-one-time-machine-setup)
3. [Start a new project from scratch](#2-start-a-new-project-from-scratch)
4. [Put an existing online project on your Mac](#3-put-an-existing-online-project-on-your-mac)
5. [Put a live site that isn't on git on your Mac](#4-put-a-live-site-that-isnt-on-git-on-your-mac)
6. [Command reference](#command-reference)
7. [Options](#options)
8. [Configuration files](#configuration-files)
9. [Resume, re-run a step, troubleshooting](#resume-re-run-a-step-troubleshooting)
10. [Safety guarantees](#safety-guarantees)
11. [Development](#development)

---

## Requirements

- macOS 12.3 or later (`wpb` uses `readlink -f`).
- Homebrew packages: `bash` (4+), `wp-cli`, `httpd`, `mysql-client` or MariaDB/MySQL, `dnsmasq`
  and `nvm`.
- SSH access to the staging server. The sync commands expect a RunCloud-style layout: the site
  lives in `~/webapps/<app>` of the SSH user.
- Optional: a **starter** repository, needed only for `wpb new` and `wpb starter:refresh`. See
  [The starter](#the-starter).

---

## 1. One-time machine setup

### 1.1 Install the tools

```bash
brew install bash wp-cli httpd mariadb dnsmasq nvm
brew services start mariadb
brew services start httpd
nvm install 24        # or whatever your projects' frontend_tools/.nvmrc asks for
```

### 1.2 Resolve `*.stage` to your Mac (dnsmasq)

```bash
echo 'address=/.stage/127.0.0.1' >> "$(brew --prefix)/etc/dnsmasq.conf"
sudo brew services start dnsmasq
sudo mkdir -p /etc/resolver
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/stage
```

This is the only step that needs `sudo`, and you only do it once.

### 1.3 Install wpb

```bash
git clone https://github.com/GioManara96/wp-bootstrap.git ~/path/to/wp-bootstrap
echo 'alias wpb="/opt/homebrew/bin/bash ~/path/to/wp-bootstrap/wpb"' >> ~/.zshrc
source ~/.zshrc
```

On Intel Macs use `/usr/local/bin/bash`. You can also symlink `wpb` into a folder on your `PATH`
instead of using the alias.

### 1.4 Run the setup

```bash
wpb setup
```

`wpb setup` asks for:

| Prompt | Default | Notes |
|---|---|---|
| Sites directory | `~/Sites` | Where every project folder lives |
| MySQL admin user | `root` | Used only to create databases and users. On Homebrew MariaDB, root often uses socket auth: try your macOS username with an empty password |
| MySQL admin password | *(kept)* | Press Enter to keep the current one |
| Local DB password for projects | `password` | Shared by every local project DB user. Must not contain `'` or `\` |
| Internal starter repo path | *(none)* | Path to your starter clone. Leave empty if you don't use `wpb new` |

Then it:

1. Saves `~/.config/wpb/config` with mode `600`.
2. Checks the MySQL login and the dnsmasq configuration.
3. Appends **one** wildcard block at the end of your Apache vhosts file. It backs the file up
   first, runs `httpd -t`, and restores the backup if the syntax check fails. Then it restarts
   Apache.

`wpb setup` is safe to run again. Per-site vhost blocks that were already in the file keep
working, because Apache matches them before the wildcard.

Quick check:

```bash
mkdir ~/Sites/hello && echo ok > ~/Sites/hello/index.html
curl http://hello.stage     # → ok
rm -r ~/Sites/hello
```

---

## 2. Start a new project from scratch

Before you run anything:

- The machine setup is done and `wpb setup` knows your starter path.
- You created an **empty** Git repository: no README, no license, no initial commit.

```bash
wpb new git@git.example.com:group/acme-hotel.git
```

This takes about a minute and does the following:

| Step | What happens |
|---|---|
| Preflight | `~/Sites/acme-hotel` must not exist, `acme-hotel.stage` must not be claimed by an old vhost, and the remote repository must be empty |
| Starter copy | The starter is copied without its git history, and its child theme is renamed to `acme-hotel` |
| Git | `git init -b main`, `origin` set, and `.env`, `.bootstrap-state`, `tmp/` excluded locally |
| Frontend tools | `npm install` in `frontend_tools/` runs in the background. Log: `tmp/npm-install.log` |
| `.env` | `LOCAL_URL` is set; the remote keys stay empty for now |
| WordPress | Core download (your locale, falling back to `en_US`), DB `acme_hotel_db` with user `acme_hotel_user`, and `wp-config.php` |
| Install | `wp core install` with admin `admin` / `admin`, language, `/%postname%/` permalinks, then the theme and every starter plugin are activated |
| First push | Initial commit, pushed to `main`. The push is refused if `wp-config.php` or `.env` would be committed |

Open `http://acme-hotel.stage/wp-admin` and log in with `admin` / `admin`.

**When the staging server exists**, for example once the hosting app and deploy webhook are
created:

```bash
cd ~/Sites/acme-hotel
wpb db:push        # asks once for the 4 remote values, backs up the remote DB, asks to confirm
wpb assets:push    # uploads wp-content/uploads (never overwrites existing remote files)
```

Use `--name <name>` to pick a folder name other than the repository name.

---

## 3. Put an existing online project on your Mac

Before you run anything:

- The machine setup is done.
- You have read access to the repository and SSH access to the staging server.

```bash
wpb get git@git.example.com:group/acme-hotel.git
```

`wpb get` asks **once** for the 4 remote values and saves them in the project's `.env`.

| Prompt | What it is |
|---|---|
| SSH user | The system user that owns the web app on the server |
| Server IP/host | The server's IP address or hostname |
| Web app name | The app folder name under `~/webapps/` |
| Remote URL | The staging URL, e.g. `https://staging.example.com` |

Then it runs, in order:

1. `git clone`
2. `.env`
3. WordPress core
4. Local DB and user
5. `wp-config.php`
6. `.htaccess`, if the repository doesn't have one
7. **`plugins:pull`**, which fills plugin files the repository doesn't version, such as `dist/`
   folders
8. **`db:pull`**, which imports the staging DB and search-replaces the URLs

The site is then at `http://acme-hotel.stage`. Log in with the staging credentials, because the
database came from staging.

Useful variants:

```bash
wpb get <url> --name acme-hotel-v2   # different folder / domain
wpb get <url> --no-pull              # skip plugins:pull and db:pull (e.g. staging not ready yet)
```

### Projects already on your Mac, not created by wpb

The sync commands work in any WordPress folder. Run one inside the project; the first time it
asks for the 4 remote values and writes `.env`:

```bash
cd ~/Sites/some-project
wpb db:pull        # or wpb ssh, wpb assets:pull, …
```

To have it served at `<folder>.stage`, the folder name must be a valid domain label
(`a-z`, `0-9`, `-`).

---

## 4. Put a live site that isn't on git on your Mac

The site already runs on RunCloud but has no repository and no local copy, for example when
you're asked to test or take over a site. Neither `new` (it starts from the starter) nor `get`
(it takes the theme from the repository) fits: use `wpb adopt`.

```bash
wpb adopt git@git.example.com:group/acme-hotel.git   # with a new, EMPTY repository
wpb adopt --name acme-hotel                          # no repository: local only
```

It asks for the same 4 remote values as `wpb get`, then runs, in order:

1. `git init` (plus `origin` when you pass a URL)
2. `.gitignore` from the standard WordPress template, if the project doesn't have one
3. `.env`
4. **`code_pull`**: `rsync` of `wp-content/themes`, `plugins` and `mu-plugins` from the server.
   Uploads are not copied; run `wpb assets:pull` when you need them
5. WordPress core, local DB and user, `wp-config.php`, `.htaccess`
6. **`db:pull`**
7. With a URL only: the first commit and push to `main`. Without one, nothing leaves your Mac;
   publish later with `git remote add origin <url> && git push -u origin main`

Log in with the credentials of the live site. Before the first push, `wpb adopt` checks that the
repository is empty, like `wpb new`.

---

## Command reference

Run every command except `setup`, `new`, `get`, `adopt` and `starter:refresh` **inside a project folder**.
That is the folder that holds `wp-config.php`.

| Command | What it does | Options it uses |
|---|---|---|
| `wpb setup` | One-time machine setup (see [section 1](#1-one-time-machine-setup)) | `--dry-run` |
| `wpb new <empty-repo-url>` | New project from the starter, first push | `--name`, `--force-step`, `--dry-run` |
| `wpb get <repo-url>` | Existing project: clone → `.env` → core → DB → wp-config → `plugins:pull` → `db:pull` | `--name`, `--no-pull`, `--force-step`, `--dry-run` |
| `wpb adopt [<empty-repo-url>]` | Live site without git: `git init` → `.gitignore` → `.env` → themes/plugins/mu-plugins from the server → core → DB → wp-config → `db:pull` → first push (with a URL) | `--name` (required without a URL), `--force-step`, `--dry-run` |
| `wpb db:pull` | Replaces the **local** DB with the staging DB (details below) | `--dry-run` |
| `wpb db:push` | Replaces the **staging** DB with the local DB (details below) | `--yes`, `--dry-run` |
| `wpb plugins:pull` | `rsync --ignore-existing` of the remote `wp-content/plugins` into the local one (adds missing files only) | `--dry-run` |
| `wpb assets:pull` | `rsync --ignore-existing` of the remote `wp-content/uploads` into the local one | `--dry-run` |
| `wpb assets:push` | `rsync --ignore-existing` of the local `wp-content/uploads` to the remote | `--dry-run` |
| `wpb ssh` | Opens a shell on the server, already inside `~/webapps/<app>` | `--dry-run` |
| `wpb starter:refresh` | For each plugin/theme in the starter, copies the newest version found in `~/Sites/*/wp-content`, after a confirmation table | `--yes`, `--dry-run` |
| `wpb help` | Shows the built-in help | |

**`wpb db:pull` in detail:**

1. It streams the staging dump over ssh. No file is written on the server.
2. It backs up the local DB to `tmp/pre-pull-<date>.sql`.
3. It imports the dump.
4. It sets the table prefix, read from the remote and checked against the dump.
5. It search-replaces the remote URLs with the local URL: `REMOTE_URL` and the `home` and
   `siteurl` found in the dump, each with both `http://` and `https://`, plain and JSON-escaped
   (`https:\/\/…`, as Elementor and blocks store them).
6. If the remote `home` differs from `REMOTE_URL` only by scheme (for example you typed `http://`
   and the site runs on `https://`), it fixes `REMOTE_URL` in `.env` and says so. It warns when
   `home` or `siteurl` still don't point to the local URL.
7. It flushes the permalinks and, when Elementor is active, regenerates its CSS.

**`wpb db:push` in detail:**

1. It checks that the local and remote table prefixes match.
2. It shows the target URL and `user@host:webapps/app`, then asks for confirmation.
3. It backs up the remote DB to `~/wpb-backups/` on the server, outside the web root.
4. It streams the import and search-replaces the local URL with the remote URL, plain and
   JSON-escaped.

## Options

| Option | Applies to | Effect |
|---|---|---|
| `--name <name>` | `new`, `get`, `adopt` | Folder and domain name (`<name>.stage`). Default: the repository name, lowercased. Allowed: `a-z`, `0-9`, `-` |
| `--no-pull` | `get` | Skips `plugins:pull` and `db:pull` |
| `--force-step <id>` | `new`, `get`, `adopt` | Re-runs one step even if it is marked done (ids below) |
| `--dry-run` | all | Prints what would happen and changes nothing |
| `--yes`, `-y` | `db:push`, `starter:refresh` | Skips the confirmation |
| `--help`, `-h` | all | Shows the help |

Options go **after** the command: `wpb get <url> --no-pull`.

**Step ids for `--force-step`:** `starter_copy`, `clone`, `git_init`, `git_exclude`,
`gitignore`, `frontend_tools`, `env_file`, `code_pull`, `core_download`, `db_create`,
`wp_config`, `htaccess`, `tmp_folder`, `wp_install`, `first_push`, `plugins_pull`, `first_pull`.

---

## Configuration files

### `~/.config/wpb/config`

This file is machine-wide and written by `wpb setup`, with mode 600. It is never committed. You
can edit it by hand.

| Key | Default | Meaning |
|---|---|---|
| `SITES_DIR` | `~/Sites` | Parent folder of all projects |
| `MYSQL_ADMIN_USER` / `MYSQL_ADMIN_PASSWORD` | `root` / empty | Account used to create DBs and users |
| `LOCAL_DB_PASSWORD` | `password` | Password of every local project DB user |
| `STARTER_REPO` | empty | Path to the starter repository clone |
| `WP_LOCALE` | `it_IT` | Locale for `wp core download` and the language pack |
| `WP_MEMORY_LIMIT` | `768M` | Written to `wp-config.php` |
| `LOCAL_TLD` | `stage` | Local domain suffix |
| `VHOST_FILE` | *(auto)* | Apache vhosts file, if auto-detection fails |

### `<project>/.env`

This file belongs to one project and is never committed: it is added to `.git/info/exclude`,
and Apache refuses to serve it.

```
REMOTE_SSH_USER=
REMOTE_SSH_HOST=
REMOTE_APP_NAME=
REMOTE_URL=
LOCAL_URL=
```

Remote commands connect as `REMOTE_SSH_USER@REMOTE_SSH_HOST`. If you need a special key or
port, add a `Host` entry for that host in `~/.ssh/config`.

### Naming

| Item | Value |
|---|---|
| Folder | `~/Sites/<name>` |
| URL | `http://<name>.stage` |
| DB name | `<name>_db` (dashes become underscores) |
| DB user | `<name>_user` (dashes become underscores) |

For example, `acme-hotel` gives `acme_hotel_db` and `acme_hotel_user`.

### The starter

The starter is a separate, usually private, repository. `wpb` needs a `starter/` folder at its
root containing:

- `wp-content/themes/` with exactly **one** child theme. Its `style.css` has a `Template:` line
  and `Theme Name: {{THEME_NAME}}`.
- `wp-content/plugins/`, holding every plugin a new project should start with.
- `.gitignore` and `.env.example`.
- Optionally `frontend_tools/`, which gets `npm install` and uses `.nvmrc` if present.

Keep its plugins current with `wpb starter:refresh`, then commit in the starter repository.
Licenses of premium plugins are activated per site.

---

## Resume, re-run a step, troubleshooting

- **A command stopped halfway.** Fix the cause and run the **same command again**, with the
  same `--name` if you used one. Finished steps are skipped, because progress is stored in
  `<project>/.bootstrap-state`. The error message prints the exact command to re-run.
- **Redo one step.** Use `wpb get <url> --force-step wp_config`, for example.
- **"already served by a legacy vhost".** A per-site `<VirtualHost>` block written by hand in the
  vhosts file already uses that domain, and it takes precedence over the wildcard. Pass `--name` with another name, or remove the old block.
- **`code_pull`: "no WordPress in user@host:webapps/app".** `REMOTE_APP_NAME` (or the SSH
  values) in `.env` is wrong. List the apps with `ssh user@host ls webapps`, fix `.env`, re-run.
- **"Database … already exists".** `wpb` never drops databases. Drop it yourself if it's
  leftover, or use `--name`.
- **"table prefix mismatch" on `db:push`.** The staging install uses a different prefix than
  the local one (`wp_` for `wpb new`). Create the staging app with the same prefix, or pull
  first with `wpb db:pull`, which adopts the remote prefix.
- **"Cannot connect to MySQL".** Run `wpb setup` again. On Homebrew MariaDB, try your macOS
  username with an empty password.
- **`*.stage` doesn't resolve.** Check `/etc/resolver/stage` and `sudo brew services list` for
  dnsmasq.
- **A site doesn't respond after setup.** Run `brew services restart httpd`.
- **A plugin didn't activate after `new`.** Check wp-admin → Plugins. `wpb` retries once for
  plugins that depend on each other.
- **`npm install` failed.** Read `tmp/npm-install.log`, then run
  `cd frontend_tools && npm install`.

---

## Safety guarantees

- No database is ever dropped, locally or remotely.
- The local DB is backed up before `db:pull`, and the remote DB is backed up before `db:push`.
- Dumps are streamed over ssh, so SQL files never sit in the public web root.
- `db:push` refuses to run when the table prefixes differ, and always asks for confirmation
  unless you pass `--yes`.
- Remote values from `.env` are validated before they reach any ssh command.
- Apache denies `.env*`, `.bootstrap-state`, `.git/` and the logs folder for **every** local
  site. Directory listing is off.
- `wpb new` and `wpb adopt` refuse to push `wp-config.php` or `.env`, and push only into an
  empty repository.

---

## Development

```bash
bash tests/run-all.sh        # unit tests, no network, no real DB/Apache/ssh
```

Layout:

- `wpb` is the entry point.
- `lib/*.sh` holds small libraries.
- `lib/steps/` holds the skip-if-done steps.
- `lib/commands/` holds one file per command.
- `templates/` holds the `wp-config`, `.htaccess` and vhost templates.
