#!/usr/bin/env bash
# Install the php2shell Claude Code skill.
#   curl -fsSL https://raw.githubusercontent.com/DavidHuji/PHP2Shell-SKILL/main/install.sh | bash
#   ... | bash -s -- --project     # install into ./.claude/skills (commit it, the whole team gets it)
set -eu

REPO="https://github.com/DavidHuji/PHP2Shell-SKILL"
dest="$HOME/.claude/skills/php2shell"
[ "${1:-}" = "--project" ] && dest="$PWD/.claude/skills/php2shell"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"

mkdir -p "$(dirname "$dest")"
rm -rf "$dest"
cp -R "$tmp"/PHP2Shell-SKILL-main/skills/php2shell "$dest"
chmod +x "$dest/php2shell.sh"

echo "✔ Installed to $dest"
echo
echo "In Claude Code:   /php2shell"
echo "Without Claude:   bash $dest/php2shell.sh check"
