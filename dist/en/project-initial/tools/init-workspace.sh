#!/bin/sh
# Initialize the file naming and update spec in a directory (the tool-neutral part).
# Copies SPEC.md, templates and tools, generates INDEX.md and .gitignore, creates the folders,
# and runs git init (without committing) when the target is not inside another git repository.
# Existing files are never overwritten.
# Usage: sh tools/init-workspace.sh [--adapter <name>] <target-dir>
#   --adapter: also run adapters/<name>/install.sh to write that tool's instruction file
#              and permission settings.

set -u

PKG=$(cd "$(dirname "$0")/.." && pwd -P) || exit 2
. "$PKG/tools/messages.sh"
fmt() { _f=$1; shift; printf "$_f" "$@"; }

usage() { fmt "$I_USAGE" "$0"; echo; }

ADAPTER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --adapter)
      if [ $# -lt 2 ]; then printf '%s\n' "$I_ADAPTER_NEEDS_NAME" >&2; exit 2; fi
      ADAPTER=$2
      shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    --*)
      fmt "$I_UNKNOWN_OPTION" "$1" >&2; echo >&2; usage >&2; exit 2 ;;
    *)
      break ;;
  esac
done

if [ $# -lt 1 ]; then
  usage >&2
  exit 2
fi

# Validate the adapter before creating anything.
if [ -n "$ADAPTER" ]; then
  case "$ADAPTER" in
    ""|*[!a-z0-9-]*)
      fmt "$I_BAD_ADAPTER_NAME" "$ADAPTER" >&2; echo >&2; exit 2 ;;
  esac
  if [ ! -f "$PKG/adapters/$ADAPTER/install.sh" ]; then
    fmt "$I_NO_ADAPTER" "$ADAPTER" >&2; echo >&2
    printf '%s\n' "$I_ADAPTERS_AVAILABLE" >&2
    for d in "$PKG"/adapters/*/; do
      [ -f "${d}install.sh" ] && echo "  $(basename "$d")" >&2
    done
    exit 2
  fi
fi

mkdir -p "$1" || exit 2
TARGET=$(cd "$1" && pwd -P) || exit 2
cd "$TARGET" || exit 2

VERSION=$(tr -d '[:space:]' < "$PKG/VERSION")
TODAY=$(date +%Y-%m-%d)

# Copy one file unless the destination exists.
put() {
  if [ -e "$2" ]; then
    fmt "$I_EXISTS" "$2"; echo
  else
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    fmt "$I_CREATED" "$2"; echo
  fi
}

for d in experiments docs/plans docs/decisions src data/raw data/interim data/processed archive external; do
  mkdir -p "$d"
done

put "$PKG/SPEC.md" SPEC.md
for f in "$PKG"/templates/*.md; do
  put "$f" "templates/$(basename "$f")"
done
put "$PKG/tools/check-workspace.sh" tools/check-workspace.sh
put "$PKG/tools/pull-external.sh" tools/pull-external.sh
put "$PKG/tools/messages.sh" tools/messages.sh

if [ -e INDEX.md ]; then
  fmt "$I_EXISTS" INDEX.md; echo
else
  sed -e "s/{{SPEC_VERSION}}/$VERSION/" -e "s/{{INIT_DATE}}/$TODAY/" "$PKG/templates/INDEX.md" > INDEX.md
  fmt "$I_CREATED" INDEX.md; echo
fi

if [ -e .gitignore ]; then
  printf '%s\n' "$I_GITIGNORE_EXISTS"
else
  {
    printf '%s\n' "$GI_EXTERNAL"
    printf '%s\n\n' "external/"
    printf '%s\n' "$GI_DATA"
    cat <<'GITIGNORE'
data/**
!data/**/
!data/**/MANIFEST.md
**/results/**/*.pt
**/results/**/*.bin
**/results/**/*.ckpt
**/results/**/*.safetensors

.DS_Store
GITIGNORE
  } > .gitignore
  fmt "$I_CREATED" .gitignore; echo
fi

if ! command -v git >/dev/null 2>&1; then
  printf '%s\n' "$I_GIT_MISSING"
else
  top=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$top" ]; then
    git -C "$TARGET" init -q && printf '%s\n' "$I_GIT_INIT"
  elif [ "$top" = "$TARGET" ]; then
    printf '%s\n' "$I_GIT_EXISTS"
  else
    fmt "$I_GIT_NESTED" "$top"; echo
  fi
fi

if [ -n "$ADAPTER" ]; then
  echo
  fmt "$I_ADAPTER_INSTALL" "$ADAPTER"; echo
  if ! sh "$PKG/adapters/$ADAPTER/install.sh" "$TARGET" "$PKG"; then
    fmt "$I_ADAPTER_FAILED" "$ADAPTER" >&2; echo >&2
    exit 1
  fi
fi

echo
printf '%s\n' "$I_INITIAL_CHECK"
sh tools/check-workspace.sh "$TARGET"
echo
printf '%s\n' "$I_DONE"
