#!/bin/sh
# Claude Code adapter. Called by `tools/init-workspace.sh --adapter claude-code`; it can also be run alone.
# It does three things:
#   1. Writes the spec block into CLAUDE.md. Appends to an existing file; when only AGENTS.md exists,
#      the new CLAUDE.md imports it first.
#   2. Creates .claude/settings.json (read and edit limits, external instruction files excluded).
#      An existing file is not overwritten.
#   3. Adds the machine-local settings files to .gitignore.
# Usage: sh install.sh <target-dir> <package-dir>

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 2
. "$HERE/../../tools/messages.sh"
fmt() { _f=$1; shift; printf "$_f" "$@"; }

if [ $# -ne 2 ]; then
  fmt "$A_USAGE" "$0" >&2; echo >&2
  exit 2
fi
TARGET=$1
PKG=$2
cd "$TARGET" || exit 2

VERSION=$(tr -d '[:space:]' < "$PKG/VERSION")
TMP=$(mktemp) || exit 2
trap 'rm -f "$TMP"' EXIT

mkdir -p .claude

# The block is wrapped in block-level HTML comments. Claude Code strips them before injecting the file into context.
{
  printf '<!-- spec:begin v%s -->\n' "$VERSION"
  cat "$PKG/templates/agent-rules.md"
  printf '<!-- spec:end -->\n'
} > "$TMP"

if [ -e CLAUDE.md ]; then
  if grep -q '<!-- spec:begin' CLAUDE.md; then
    printf '%s\n' "$A_BLOCK_PRESENT"
  else
    { printf '\n'; cat "$TMP"; } >> CLAUDE.md
    printf '%s\n' "$A_BLOCK_APPENDED"
  fi
elif [ -e AGENTS.md ]; then
  # Claude Code stops reading AGENTS.md once a CLAUDE.md exists, so import it explicitly.
  { printf '@AGENTS.md\n\n'; cat "$TMP"; } > CLAUDE.md
  printf '%s\n' "$A_CREATED_IMPORT"
else
  cp "$TMP" CLAUDE.md
  printf '%s\n' "$A_CREATED"
fi

if [ -e .claude/settings.json ]; then
  fmt "$A_SETTINGS_EXISTS" "$HERE/settings.json"; echo
else
  cp "$HERE/settings.json" .claude/settings.json
  printf '%s\n' "$A_SETTINGS_CREATED"
fi

touch .gitignore
if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then
  printf '\n' >> .gitignore
fi
for line in '.claude/settings.local.json' 'CLAUDE.local.md'; do
  grep -qxF "$line" .gitignore || printf '%s\n' "$line" >> .gitignore
done
printf '%s\n' "$A_GITIGNORE"
