#!/usr/bin/env bash
# Run the scanner against the fixtures and compare with the expected verdicts.
set -u
cd "$(dirname "$0")/.." || exit 1
S=skills/php2shell/php2shell.sh
fail=0

expect() {
  if grep -qF -- "$2" <<<"$1"; then echo "pass: $2"; else echo "FAIL: missing '$2'"; fail=1; fi
}

out=$(bash "$S" check --project-only tests/fixtures/vulnerable); code=$?
[ "$code" = 1 ] && echo "pass: exit 1 on vulnerable" || { echo "FAIL: exit $code on vulnerable"; fail=1; }
expect "$out" "docker/Dockerfile: PHP 8.3.10 is vulnerable → bump to 8.3.36"
expect "$out" "Dockerfile.old: PHP 8.1.2 has no official fix"
expect "$out" "docker-compose.yml: floating PHP 8.4 tag"
expect "$out" ".github/workflows/ci.yml: PHP 8.4.27 is patched"
expect "$out" ".php-version: PHP 8.5.11 is vulnerable → bump to 8.5.12"
expect "$out" ".tool-versions: PHP 8.2.35 is patched"
expect "$out" "composer.json: PHP 8.2.1 is vulnerable → bump to 8.2.35"
if grep -q "vendor/" <<<"$out"; then echo "FAIL: vendor/ was scanned"; fail=1; else echo "pass: vendor/ skipped"; fi

ann=$(GITHUB_ACTIONS=true bash "$S" check --project-only tests/fixtures/vulnerable)
expect "$ann" "::error file=tests/fixtures/vulnerable/docker/Dockerfile,line=1,title=PHP2Shell::"

out=$(bash "$S" check --project-only tests/fixtures/clean); code=$?
[ "$code" = 0 ] && echo "pass: exit 0 on clean" || { echo "FAIL: exit $code on clean"; fail=1; }

exit $fail
