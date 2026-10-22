#!/usr/bin/env bash
# Word splitting of file / binary lists is intentional.
# shellcheck disable=SC2046,SC2086
# php2shell - check, mitigate and hunt for PHP2Shell (CVE-2026-109618 / CVE-2026-109619).
#
#   php2shell.sh check [dir]       scan a project + this machine (read-only, default)
#                  --project-only  skip local PHP / Docker (use this in CI)
#   php2shell.sh mitigate [--apply] write the server ini drop-in (dry run by default)
#   php2shell.sh hunt              look for signs of exploitation (read-only)
set -u

FIXED="8.2.35 8.3.36 8.4.27 8.5.12"
SELF=$0; [ -f "$SELF" ] || SELF=php2shell.sh   # "bash" when piped from curl

if [ -t 1 ]; then R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else R='' G='' Y='' B='' N=''; fi
# In GitHub Actions, findings in project files also become inline annotations.
annotate() {
  [ "${GITHUB_ACTIONS:-}" = true ] && [ -n "${CUR_FILE:-}" ] || return 0
  local line
  line=$(grep -n -F "${CUR_VER:-}" "$CUR_FILE" 2>/dev/null | head -n1 | cut -d: -f1)
  echo "::$1 file=${CUR_FILE#./},line=${line:-1},title=PHP2Shell::$2"
}
ok()   { echo "  ${G}✔${N} $*"; }
bad()  { echo "  ${R}✘${N} $*"; FOUND_BAD=1; annotate error "$*"; }
warn() { echo "  ${Y}!${N} $*"; annotate warning "$*"; }
head_() { echo; echo "${B}$*${N}"; }
FOUND_BAD=0

# fixed_patch 8.3 -> 36 (empty if branch has no official fix)
fixed_patch() {
  for f in $FIXED; do [ "${f%.*}" = "$1" ] && { echo "${f##*.}"; return; }; done
}

# judge <version> <where>: prints one verdict line
judge() {
  local ver=$1 where=$2 branch patch need
  case "$ver" in
    [0-9]*.[0-9]*.[0-9]*) branch=$(echo "$ver" | cut -d. -f1-2); patch=$(echo "$ver" | cut -d. -f3 | sed 's/[^0-9].*//') ;;
    [0-9]*.[0-9]*)        branch=$(echo "$ver" | cut -d. -f1-2); patch= ;;
    *) return ;;
  esac
  need=$(fixed_patch "$branch")
  if [ -z "$need" ]; then
    bad "$where: PHP $ver has no official fix → move to 8.2.35+ (or a supported branch)"
  elif [ -z "$patch" ]; then
    warn "$where: floating PHP $ver tag → rebuild with --pull so it picks up $branch.$need+"
  elif [ "$patch" -ge "$need" ]; then
    ok "$where: PHP $ver is patched"
  else
    bad "$where: PHP $ver is vulnerable → bump to $branch.$need"
  fi
}

scan_project() {
  local dir=${1:-.} f v
  head_ "Project files in $dir"
  local files
  files=$(find "$dir" -maxdepth 5 \( -name vendor -o -name node_modules -o -name .git \) -prune -o -type f \
    \( -name 'Dockerfile*' -o -name '*.dockerfile' -o -name 'docker-compose*.y*ml' -o -name 'compose*.y*ml' \
       -o -name '.php-version' -o -name '.tool-versions' -o -name composer.json -o -path '*/.github/workflows/*.y*ml' \
       -o -name '.gitlab-ci.yml' \) -print 2>/dev/null)
  [ -z "$files" ] && { echo "  (no Dockerfiles, CI configs or version files found)"; return; }

  local hits=0
  for f in $files; do
    rel=${f#"$dir"/}
    case "$f" in
      *Dockerfile*|*.dockerfile)
        vers=$(sed -nE 's/^[[:space:]]*FROM[[:space:]]+([^[:space:]]*\/)?php:([0-9][0-9.]*).*/\2/Ip' "$f") ;;
      *compose*.y*ml|*.gitlab-ci.yml)
        vers=$(sed -nE 's/.*image:[[:space:]]*["'\'']?([^[:space:]"'\'']*\/)?php:([0-9][0-9.]*).*/\2/p' "$f") ;;
      */.github/workflows/*)
        vers=$(sed -nE 's/.*php-version:[[:space:]]*["'\'']?([0-9][0-9.]*).*/\1/p' "$f") ;;
      *.php-version)
        vers=$(head -n1 "$f" | tr -d '[:space:]') ;;
      *.tool-versions)
        vers=$(sed -nE 's/^php[[:space:]]+([0-9][0-9.]*).*/\1/p' "$f") ;;
      *composer.json)
        vers=$(tr -d '\n' < "$f" | sed -nE 's/.*"platform"[[:space:]]*:[[:space:]]*\{[^}]*"php"[[:space:]]*:[[:space:]]*"([0-9][0-9.]*)".*/\1/p') ;;
    esac
    for v in $vers; do CUR_FILE=$f CUR_VER=${v%.}; judge "${v%.}" "$rel"; hits=1; done
  done
  CUR_FILE=
  [ "$hits" = 0 ] && echo "  (no pinned PHP versions found in project files)"
}

scan_machine() {
  head_ "PHP on this machine"
  local bins bin ver any=0
  bins=$( { command -v php; ls /usr/bin/php[0-9]* /usr/local/bin/php* /opt/homebrew/bin/php /opt/remi/*/root/usr/bin/php \
            /usr/sbin/php-fpm* 2>/dev/null; } | sort -u )
  for bin in $bins; do
    [ -x "$bin" ] || continue
    ver=$("$bin" -r 'echo PHP_VERSION;' 2>/dev/null) || ver=$("$bin" -v 2>/dev/null | sed -n 's/^PHP \([0-9.]*\).*/\1/p')
    [ -n "$ver" ] || continue
    any=1
    judge "$ver" "$bin"
    up=$("$bin" -i 2>/dev/null | sed -n 's/^session\.upload_progress\.enabled => \([^ ]*\).*/\1/p')
    [ "$up" = "On" ] && warn "$bin: session.upload_progress.enabled is On (mitigation not applied)"
  done
  [ "$any" = 0 ] && echo "  (no local PHP found)"

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    head_ "Running Docker containers"
    local name anyc=0
    for name in $(docker ps --format '{{.Names}}' 2>/dev/null); do
      ver=$(docker exec "$name" php -r 'echo PHP_VERSION;' 2>/dev/null) || continue
      anyc=1
      judge "$ver" "container $name"
    done
    [ "$anyc" = 0 ] && echo "  (no running containers with PHP)"
  fi
}

cmd_check() {
  echo "${B}PHP2Shell check${N} (CVE-2026-109618 / CVE-2026-109619). Fixed in: $FIXED"
  local dir=. machine=1 a
  for a in "$@"; do
    case "$a" in --project-only) machine=0 ;; *) dir=$a ;; esac
  done
  scan_project "$dir"
  [ "$machine" = 1 ] && scan_machine
  echo
  if [ "$FOUND_BAD" = 1 ]; then
    echo "${R}${B}Action needed.${N} Bump the versions above. If a server can't be patched today: $SELF mitigate"
    exit 1
  fi
  echo "${G}${B}No vulnerable PHP found.${N} After upgrading a server, restart PHP-FPM / Apache."
}

cmd_mitigate() {
  local apply=0 name=99-php2shell.ini dirs d bin
  [ "${1:-}" = "--apply" ] && apply=1
  local content='; PHP2Shell mitigation (CVE-2026-109618 / CVE-2026-109619)
; Remove once PHP is upgraded to a fixed release.
session.upload_progress.enabled = 0
session.use_strict_mode = 1'

  dirs=$( { ls -d /etc/php/*/fpm/conf.d /etc/php/*/apache2/conf.d /etc/php/*/cli/conf.d 2>/dev/null
            for bin in $(command -v php) /usr/bin/php[0-9]* /usr/sbin/php-fpm*; do
              [ -x "$bin" ] && "$bin" -i 2>/dev/null | sed -n 's/^Scan this dir for additional .ini files => \(.*\)$/\1/p'
            done; } | grep -v '(none)' | sort -u )

  echo "$content"; echo
  if [ -z "$dirs" ]; then
    echo "No conf.d directory found. Add the lines above to php.ini or the FPM pool."
    echo "Docker: COPY a file with these lines to /usr/local/etc/php/conf.d/$name"
    exit 1
  fi
  for d in $dirs; do
    if [ "$apply" = 1 ]; then printf '%s\n' "$content" > "$d/$name" && ok "wrote $d/$name"
    else echo "  would write $d/$name"; fi
  done
  echo
  if [ "$apply" = 1 ]; then echo "Done. Restart PHP-FPM / Apache, then run: $SELF check"
  else echo "Dry run. Re-run with --apply (usually with sudo) to write."; fi
}

cmd_hunt() {
  echo "${B}PHP2Shell hunt${N} (read-only). A clean result does not prove the host wasn't hit."
  local logs root d
  logs=$(ls /var/log/php*.log /var/log/php*/*.log /var/log/php-fpm/*.log \
            /var/log/apache2/error.log /var/log/httpd/error_log /var/log/nginx/error.log 2>/dev/null)

  head_ "Out-of-memory / timeout fatals"
  [ -n "$logs" ] && grep -hE 'Allowed memory size .* exhausted|Out of memory|Maximum execution time' $logs 2>/dev/null | tail -n 20

  head_ "PHP worker crashes"
  [ -n "$logs" ] && grep -hiE 'SIGSEGV|segfault|exited on signal 11' $logs 2>/dev/null | tail -n 20

  head_ "Shells started by PHP"
  ps -eo pid=,ppid=,user=,args= 2>/dev/null | while read -r pid ppid user cmd; do
    parent=$(ps -o comm= -p "$ppid" 2>/dev/null)
    case "$parent" in *php*|*apache2*|*httpd*)
      case "$cmd" in *sh|*sh\ *|*bash*|*nc\ *|*curl\ *|*wget\ *|*python*|*perl*) echo "  $pid ($parent) $user $cmd" ;; esac ;;
    esac
  done

  head_ ".php files changed in the last 3 days"
  for root in /var/www /srv /usr/share/nginx/html /home/*/public_html; do
    [ -d "$root" ] && find "$root" -name '*.php' -mtime -3 -type f 2>/dev/null | head -n 50
  done

  head_ "Session files with upload_progress_ keys"
  for d in $(php -r 'echo session_save_path();' 2>/dev/null) /var/lib/php/sessions /var/lib/php/session /tmp; do
    [ -d "$d" ] && grep -l 'upload_progress_' "$d"/sess_* 2>/dev/null | head -n 20
  done
  echo; echo "Done. Review anything listed above."
}

case "${1:-check}" in
  check)    shift 2>/dev/null; cmd_check "$@" ;;
  mitigate) shift; cmd_mitigate "$@" ;;
  hunt)     cmd_hunt ;;
  -h|--help|help) sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "unknown command: $1 (try: check, mitigate, hunt)"; exit 2 ;;
esac
