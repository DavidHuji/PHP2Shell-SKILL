---
name: php2shell
description: Find and fix PHP2Shell (CVE-2026-109618 / CVE-2026-109619) in a developer's project and environment. Scans Dockerfiles, docker-compose, CI workflows, .php-version/.tool-versions and composer platform pins, plus local PHP and running containers; bumps vulnerable versions; mitigates servers that can't be patched yet. Use when the user mentions PHP2Shell, these CVEs, or asks if their PHP app is affected.
---

# PHP2Shell

PHP2Shell is a pair of RCE bugs in PHP core (CVSS 9.2 each), fixed on 2026-10-21. The bugs are in the runtime, so every PHP app is affected, whatever its framework.

**Fixed in:** 8.2.35 · 8.3.36 · 8.4.27 · 8.5.12. PHP 8.1 and older have no official fix.

## Steps

The helper script is `php2shell.sh`, in the same folder as this file.

1. **Check:** run `bash <skill-dir>/php2shell.sh check <project-dir>`. It changes nothing. Each finding is marked ✔ patched, ✘ vulnerable or ! floating tag.
2. **Fix the project:** for each ✘ in project files, offer to bump the version and make the edit once the user agrees:
   - Dockerfile / compose: `php:8.3.10-fpm` → `php:8.3.36-fpm` (same branch, same suffix).
   - CI `php-version`, `.php-version`, `.tool-versions`, composer `config.platform.php`: bump to the fixed patch of the same branch.
   - Branch 8.1 or older: suggest 8.2.35+ and point out that this is a minor-version upgrade, so the tests need to pass.
   - Floating tags (`php:8.3-fpm`): no edit needed. Tell the user to rebuild with `docker build --pull` / `docker compose build --pull`.
3. **Fix the machine:** for local PHP, suggest the matching upgrade command (`brew upgrade php`, `apt install --only-upgrade php8.3*`, etc.). Don't run `sudo` yourself; ask the user to run it.
4. **Servers that can't be patched today:** run `php2shell.sh mitigate` (a dry run). Show the output, and after the user approves, have them run `sudo bash php2shell.sh mitigate --apply`. Then restart PHP-FPM / Apache and re-run `check`. This setting must go in php.ini / conf.d / the FPM pool. It has no effect in `.user.ini` or `ini_set()`.
5. **Production servers:** offer to run `php2shell.sh hunt` (read-only) to look for signs of exploitation.

End with a short summary: what was vulnerable, what you changed, and what the user still needs to do (rebuild, deploy, restart).

## Rules

- Never download or run exploit / PoC code.
- Don't edit files or change servers without the user's OK. The script never restarts services.

## References

- Wiz Research: https://www.wiz.io/blog/php2shell-php-rce
- PHP advisory: https://www.php.net/archive/2026.php#2026-10-21-5
