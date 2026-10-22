# PHP2Shell Skill for Claude Code

[![test](https://github.com/DavidHuji/PHP2Shell-SKILL/actions/workflows/test.yml/badge.svg)](https://github.com/DavidHuji/PHP2Shell-SKILL/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CVE-2026-109618](https://img.shields.io/badge/CVE-2026--109618-critical-red)](https://www.wiz.io/vulnerability-database/cve/cve-2026-109618)
[![CVE-2026-109619](https://img.shields.io/badge/CVE-2026--109619-critical-red)](https://www.wiz.io/vulnerability-database/cve/cve-2026-109619)

**Is your PHP app affected by PHP2Shell? Find out in one command, and let Claude fix it.**

PHP2Shell is a pair of critical RCE bugs in PHP itself (CVSS 9.2 each). Every PHP app is affected, whatever its framework: Laravel, Symfony, WordPress, Drupal, Magento and plain PHP alike.
**Fixed in 8.2.35 · 8.3.36 · 8.4.27 · 8.5.12.**

```text
Project files in .
  ✘ docker/Dockerfile: PHP 8.3.10 is vulnerable → bump to 8.3.36
  ✘ composer.json: PHP 8.2.1 is vulnerable → bump to 8.2.35
  ! docker-compose.yml: floating PHP 8.4 tag → rebuild with --pull so it picks up 8.4.27+
  ✔ .github/workflows/ci.yml: PHP 8.4.27 is patched
```

## Pick your install

**1. Claude Code skill (one line)**

```bash
curl -fsSL https://raw.githubusercontent.com/DavidHuji/PHP2Shell-SKILL/main/install.sh | bash
```

Then type `/php2shell` in Claude Code from your project folder. Claude scans the project, shows what's vulnerable, and offers to bump the versions for you.

**2. Claude Code plugin**

```text
/plugin marketplace add DavidHuji/PHP2Shell-SKILL
/plugin install php2shell@php2shell
```

**3. GitHub Action (keeps vulnerable PHP out of every PR)**

```yaml
# .github/workflows/php2shell.yml
name: php2shell
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: DavidHuji/PHP2Shell-SKILL@main
```

The build fails on vulnerable versions, and each finding shows up as an inline annotation on the exact line in the PR.

**4. Just the script, no install**

```bash
curl -fsSL https://raw.githubusercontent.com/DavidHuji/PHP2Shell-SKILL/main/skills/php2shell/php2shell.sh | bash -s -- check
```

## What it checks

| Where | Example |
| --- | --- |
| Dockerfiles | `FROM php:8.3.10-fpm` |
| docker-compose / GitLab CI | `image: php:8.2.20-apache` |
| GitHub Actions | `php-version: '8.4.5'` |
| Version files | `.php-version`, `.tool-versions` |
| Composer | `config.platform.php` |
| Your machine | local `php` / `php-fpm`, running Docker containers |

`vendor/` and `node_modules/` are skipped.

## Commands

```bash
php2shell.sh check [dir]                 # scan project + machine (read-only); exit 1 if vulnerable
php2shell.sh check --project-only [dir]  # project files only (what the Action runs)
php2shell.sh mitigate                    # server stopgap, dry run
sudo php2shell.sh mitigate --apply       # write the conf.d drop-in, then restart PHP-FPM / Apache
php2shell.sh hunt                        # look for signs of exploitation (read-only)
```

**Install for the whole team:** add `| bash -s -- --project` to the install command. It installs the skill into `./.claude/skills/`, and you commit it with the rest of the repo.

## Can't patch a server today?

`mitigate` writes a small `conf.d` drop-in that turns off `session.upload_progress` (the path seen exploited in the wild). Restart PHP-FPM / Apache afterwards. This is a stopgap. Upgrading PHP is the real fix.

## Credits

- **[Wiz Research](https://www.wiz.io/blog/php2shell-php-rce)** discovered and documented PHP2Shell. See also the Wiz vulnerability database entries for [CVE-2026-109618](https://www.wiz.io/vulnerability-database/cve/cve-2026-109618) and [CVE-2026-109619](https://www.wiz.io/vulnerability-database/cve/cve-2026-109619).
- **[netresearch/security-audit-skill](https://github.com/netresearch/security-audit-skill)**: the PHP security-audit skill for Claude Code that inspired this project.
- **[Sumon Selim's PHP2Shell defense write-up](https://www.sumonselim.com/php2shell-defense-patch-or-mitigate-with-a-claude-code-skill/)**: the mitigation and hunting workflow.
- The [PHP security advisory](https://www.php.net/archive/2026.php#2026-10-21-5) and the GitHub advisories [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) and [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp).

## Contributing

Found a file format it misses (Helm charts, Ansible, Platform.sh, Lando…)? Open an issue or PR. Add a fixture under `tests/fixtures/` and run `bash tests/run.sh`.

If this saved you some time, a ⭐ helps other PHP devs find it.

## License

MIT. Provided as-is, with no warranty. Review every change before it goes to production.
