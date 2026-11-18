#!/bin/sh
# Build the self-contained packages, one per language.
#
# Each package is a complete project-initial skill folder: SKILL.md, SPEC.md, VERSION, templates/,
# tools/ (including the language's messages.sh) and adapters/. It needs nothing outside itself.
#
# Usage:
#   sh scripts/build.sh                   build every language into dist/<lang>/project-initial
#   sh scripts/build.sh <lang>            build one language into dist/<lang>/project-initial
#   sh scripts/build.sh <lang> <dir>      build one language into <dir> (replaces files this script writes)
# Languages are the folders in src/i18n/.

set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
SRC="$REPO/src"

langs() {
  for d in "$SRC"/i18n/*/; do basename "$d"; done
}

# Every language must have the same files as en, and the same message keys with the same number of
# %s placeholders. A missing key would crash a tool at run time, so the build refuses to continue.
check_i18n() {
  tmp=$(mktemp -d)
  summarize() {
    awk '/^[A-Z][A-Z_]*=/ { name = $0; sub(/=.*/, "", name); val = $0; sub(/^[^=]*=/, "", val); n = gsub(/%s/, "", val); print name, n }' "$1" | sort
  }
  (cd "$SRC/i18n/en" && find . -type f ! -name .DS_Store | sort) > "$tmp/ref-files"
  summarize "$SRC/i18n/en/messages.sh" > "$tmp/ref-keys"
  bad=0
  for l in $(langs); do
    [ "$l" = en ] && continue
    (cd "$SRC/i18n/$l" && find . -type f ! -name .DS_Store | sort) > "$tmp/files"
    if ! diff "$tmp/ref-files" "$tmp/files" > "$tmp/diff"; then
      echo "i18n/$l has different files than i18n/en:" >&2
      cat "$tmp/diff" >&2
      bad=1
    fi
    if [ -f "$SRC/i18n/$l/messages.sh" ]; then
      summarize "$SRC/i18n/$l/messages.sh" > "$tmp/keys"
      if ! diff "$tmp/ref-keys" "$tmp/keys" > "$tmp/diff"; then
        echo "i18n/$l/messages.sh differs from en (key names or number of %s):" >&2
        cat "$tmp/diff" >&2
        bad=1
      fi
    fi
  done
  rm -rf "$tmp"
  [ "$bad" = 0 ] || exit 2
}

build_one() {
  lang=$1
  dest=$2
  I18N="$SRC/i18n/$lang"

  if [ ! -d "$I18N" ]; then
    echo "Unknown language: $lang" >&2
    echo "Available:" >&2
    langs | sed 's/^/  /' >&2
    exit 2
  fi

  mkdir -p "$dest"
  dest=$(cd "$dest" && pwd -P)
  case "$dest" in
    "$REPO"|"$SRC"|"$SRC"/*|/)
      echo "Refusing to write to: $dest" >&2
      exit 2 ;;
  esac

  # Remove only what this script writes, so unrelated files in the folder survive.
  rm -rf "$dest/templates" "$dest/tools" "$dest/adapters" \
         "$dest/SKILL.md" "$dest/SPEC.md" "$dest/VERSION"
  mkdir -p "$dest/templates" "$dest/tools" "$dest/adapters"

  cp "$REPO/VERSION" "$dest/VERSION"
  cp "$I18N/SKILL.md" "$I18N/SPEC.md" "$dest/"
  cp "$I18N"/templates/*.md "$dest/templates/"

  for t in init-workspace.sh check-workspace.sh pull-external.sh; do
    cp "$SRC/tools/$t" "$dest/tools/$t"
  done
  cp "$I18N/messages.sh" "$dest/tools/messages.sh"

  # Adapters: scripts and settings are language-neutral; the README is translated.
  for a in "$SRC"/adapters/*/; do
    name=$(basename "$a")
    mkdir -p "$dest/adapters/$name"
    cp "$a"* "$dest/adapters/$name/"
    if [ -f "$I18N/adapters/$name/README.md" ]; then
      cp "$I18N/adapters/$name/README.md" "$dest/adapters/$name/README.md"
    fi
  done

  find "$dest" -name .DS_Store -exec rm -f {} +
  echo "Built [$lang] -> $dest"
}

check_i18n

if [ $# -eq 0 ]; then
  for l in $(langs); do build_one "$l" "$REPO/dist/$l/project-initial"; done
elif [ $# -eq 1 ]; then
  build_one "$1" "$REPO/dist/$1/project-initial"
elif [ $# -eq 2 ]; then
  build_one "$1" "$2"
else
  echo "Usage: sh $0 [<lang> [<dir>]]" >&2
  exit 2
fi
