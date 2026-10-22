# PHP2Shell Skill for Claude Code

**Is your PHP app affected by PHP2Shell? Find out in one command, and let Claude fix it.**

PHP2Shell ([CVE-2026-109618](https://www.wiz.io/vulnerability-database/cve/cve-2026-109618) / [CVE-2026-109619](https://www.wiz.io/vulnerability-database/cve/cve-2026-109619)) is a pair of critical RCE bugs in PHP itself. Every PHP app is affected, whatever its framework.
**Fixed in 8.2.35 · 8.3.36 · 8.4.27 · 8.5.12.**

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/DavidHuji/PHP2Shell-SKILL/main/install.sh | bash
```

Then, in Claude Code, from your project folder:

```text
/php2shell
```

That's it. Claude scans your project, shows what's vulnerable, and offers to bump the versions for you.

## What it checks

| Where | Example |
| --- | --- |
| Dockerfiles | `FROM php:8.3.10-fpm` |
| docker-compose / GitLab CI | `image: php:8.2.20-apache` |
| GitHub Actions | `php-version: '8.4.5'` |
| Version files | `.php-version`, `.tool-versions` |
| Composer | `config.platform.php` |
| Your machine | local `php` / `php-fpm`, running Docker containers |

```text
Project files in .
  ✘ docker/Dockerfile: PHP 8.3.10 is vulnerable → bump to 8.3.36
  ! docker-compose.yml: floating PHP 8.4 tag → rebuild with --pull so it picks up 8.4.27+
  ✔ .github/workflows/ci.yml: PHP 8.4.27 is patched
```

## Without Claude

The script works on its own too:

```bash
bash ~/.claude/skills/php2shell/php2shell.sh check            # scan project + machine (read-only)
bash ~/.claude/skills/php2shell/php2shell.sh mitigate         # server stopgap, dry run
sudo bash ~/.claude/skills/php2shell/php2shell.sh mitigate --apply
bash ~/.claude/skills/php2shell/php2shell.sh hunt             # look for signs of exploitation
```

`check` exits with code `1` when something is vulnerable, so you can drop it into CI.

**Install for the whole team:** add `| bash -s -- --project` to the install command. It installs the skill into `./.claude/skills/`, and you commit it with the rest of the repo.

## Can't patch a server today?

`mitigate` writes a small `conf.d` drop-in that turns off `session.upload_progress` (the path seen exploited in the wild). Restart PHP-FPM / Apache afterwards. This is a stopgap. Upgrading PHP is the real fix.

## Credits

- **[Wiz Research](https://www.wiz.io/blog/php2shell-php-rce)** discovered and documented PHP2Shell. See also the Wiz vulnerability database entries for [CVE-2026-109618](https://www.wiz.io/vulnerability-database/cve/cve-2026-109618) and [CVE-2026-109619](https://www.wiz.io/vulnerability-database/cve/cve-2026-109619).
- **[netresearch/security-audit-skill](https://github.com/netresearch/security-audit-skill)**: the PHP security-audit skill for Claude Code that inspired this project.
- **[Sumon Selim's PHP2Shell defense write-up](https://www.sumonselim.com/php2shell-defense-patch-or-mitigate-with-a-claude-code-skill/)**: the mitigation and hunting workflow.
- The [PHP security advisory](https://www.php.net/archive/2026.php#2026-10-21-5) and the GitHub advisories [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) and [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp).

## License

MIT. Provided as-is, with no warranty. Review every change before it goes to production.
