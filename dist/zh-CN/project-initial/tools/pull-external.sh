#!/bin/sh
# Pull one version of an external repo into external/<ID>/ and print the row to add to INDEX.md.
# One folder per version; an existing folder is never overwritten. The remote URL must not
# contain a user name or password: authenticate with SSH keys or a git credential helper.
# Usage: sh tools/pull-external.sh <name> <remote-url> <branch-or-tag> [project-root]

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 2
. "$HERE/messages.sh"
fmt() { _f=$1; shift; printf "$_f" "$@"; }

if [ $# -lt 3 ]; then
  fmt "$P_USAGE" "$0" >&2; echo >&2
  exit 2
fi
NAME=$1
REMOTE=$2
BRANCH=$3
ROOT=${4:-.}

if ! printf '%s\n' "$NAME" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  printf '%s\n' "$P_BAD_NAME" >&2
  exit 2
fi
if printf '%s' "$REMOTE" | grep -Eq '://[^/]*@'; then
  printf '%s\n' "$P_CRED" >&2
  exit 2
fi

cd "$ROOT" || exit 2
if [ ! -f INDEX.md ]; then
  printf '%s\n' "$P_NO_INDEX" >&2
  exit 2
fi
mkdir -p external || exit 2

TMP=$(mktemp -d "external/.pull-XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT

# Never prompt: if credentials are missing, fail instead of hanging.
if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" git clone -q --single-branch --branch "$BRANCH" -- "$REMOTE" "$TMP/repo"; then
  printf '%s\n' "$P_CLONE_FAIL" >&2
  exit 1
fi

COMMIT=$(git -C "$TMP/repo" rev-parse HEAD) || exit 1
SHORT=$(printf '%s' "$COMMIT" | cut -c1-8)
ID="ext-${NAME}-${SHORT}"
DEST="external/${ID}"

if [ -e "$DEST" ]; then
  fmt "$P_EXISTS" "$DEST" >&2; echo >&2
  exit 1
fi
mv "$TMP/repo" "$DEST" || exit 1

NOW=$(date +%Y-%m-%dT%H:%M%z)
TODAY=$(date +%Y-%m-%d)
fmt "$P_PULLED" "$DEST"; echo
echo
printf '%s\n' "$P_REGISTER"
echo
echo "| ${ID} | \`${DEST}/\` | ${REMOTE} | ${BRANCH} | ${COMMIT} | ${NOW} | ${TODAY} | active | |"
