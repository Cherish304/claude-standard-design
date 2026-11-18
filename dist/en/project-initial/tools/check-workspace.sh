#!/bin/sh
# Check that a workspace follows the file naming and update spec (SPEC.md).
# Read-only by default: modifies and deletes nothing, and does not use the network.
# --remote: for active external repos, run `git ls-remote` (reads remote refs only,
#           downloads nothing) and report whether the remote has newer commits.
# The exit code is 1 when a problem is found. Hints do not affect it.
# Usage: sh tools/check-workspace.sh [--remote] [project-root]

set -u
set -f          # no globbing: [ * ? in file names must not be expanded

HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 2
. "$HERE/messages.sh"

REMOTE_CHECK=0
if [ "${1:-}" = "--remote" ]; then
  REMOTE_CHECK=1
  shift
fi
cd "${1:-.}" || exit 2

NL='
'
IFS="$NL"
fail=0

fmt() { _f=$1; shift; printf "$_f" "$@"; }
problem() { printf '%s %s\n' "$M_TAG_PROBLEM" "$(fmt "$@")"; fail=1; }
hint() { printf '%s %s\n' "$M_TAG_HINT" "$(fmt "$@")"; }
info() { printf '%s %s\n' "$M_TAG_CHECK" "$(fmt "$@")"; }

# sha256 of every non-empty file that takes part in the duplicate check.
# external/ holds copies of other repos and templates/ holds templates; both may repeat content.
hash_files() {
  if command -v sha256sum >/dev/null 2>&1; then
    find . \( -path ./.git -o -path ./node_modules -o -path ./external -o -path ./templates \) -prune -o -type f ! -empty ! -name .DS_Store -exec sha256sum {} +
  else
    find . \( -path ./.git -o -path ./node_modules -o -path ./external -o -path ./templates \) -prune -o -type f ! -empty ! -name .DS_Store -exec shasum -a 256 {} +
  fi
}

# Print one front matter field of a file. Empty when the file has no front matter.
fm() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    index($0, key ":") == 1 { sub(/^[^:]*: */, ""); sub(/ *#.*$/, ""); print; exit }
  ' "$1"
}

# Is the name mentioned in INDEX.md (substring match)?
registered() { grep -qF "$1" INDEX.md; }

if [ ! -f INDEX.md ]; then
  problem "$C_NO_INDEX"
  exit 1
fi

# 1. File names: banned words, copy suffixes, whitespace (archive/, data/raw/, external/ are skipped)
FNAME_RE='(^|[-_./])(final|new|latest|copy|old|bak|backup|tmp|test[0-9]+|v[0-9]+)([-_.]|$)|\([0-9]+\)|[[:space:]]'
[ -n "$FORBID_EXTRA" ] && FNAME_RE="$FNAME_RE|$FORBID_EXTRA"
for p in $(find . \( -path ./.git -o -path ./node_modules -o -path ./archive -o -path ./data/raw -o -path ./external \) -prune -o -print \
  | grep -E "$FNAME_RE"); do
  problem "$C_BAD_FILENAME" "$p"
done

# 2. Experiment folders: name pattern, README with front matter, registered in INDEX.md
for d in $(find experiments -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
  name=$(basename "$d")
  echo "$name" | grep -Eq '^exp-[0-9]{8}-[0-9]{2}-[a-z0-9][a-z0-9-]*$' || problem "$C_EXP_BAD_NAME" "$d"
  if [ -f "$d/README.md" ]; then
    [ -n "$(fm "$d/README.md" status)" ] || problem "$C_EXP_NO_STATUS" "$d/README.md"
  else
    problem "$C_EXP_NO_README" "$d"
  fi
  registered "$name" || problem "$C_EXP_UNREG" "$d"
done

# 3. Plans and decisions: name pattern, front matter status, registered in INDEX.md
for f in $(find docs/plans -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort); do
  b=$(basename "$f")
  echo "$b" | grep -Eq '^[0-9]{8}-[a-z0-9][a-z0-9-]*\.md$' || problem "$C_PLAN_BAD_NAME" "$f"
  [ -n "$(fm "$f" status)" ] || problem "$C_PLAN_NO_STATUS" "$f"
  registered "$b" || problem "$C_PLAN_UNREG" "$f"
done
for f in $(find docs/decisions -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort); do
  b=$(basename "$f")
  echo "$b" | grep -Eq '^[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' || problem "$C_DEC_BAD_NAME" "$f"
  [ -n "$(fm "$f" status)" ] || problem "$C_DEC_NO_STATUS" "$f"
  registered "$b" || problem "$C_DEC_UNREG" "$f"
done

# 4. Datasets: MANIFEST.md required, registered in INDEX.md
for d in $(find data/processed -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
  [ -f "$d/MANIFEST.md" ] || problem "$C_DS_NO_MANIFEST" "$d"
  registered "$(basename "$d")" || problem "$C_DS_UNREG" "$d"
done

# 5. Paths written in backticks in INDEX.md must exist (rows with status removed are skipped)
for p in $(grep -v '| removed |' INDEX.md | grep -oE '`[^`]*(/|\.md)[^`]*`' | tr -d '`' | sort -u); do
  [ -e "$p" ] || problem "$C_INDEX_MISSING" "$p"
done

# 5b. External repos: rows of INDEX.md whose ID starts with ext-.
#     ID is ext-<name>-<first 8 chars of commit>; the folder is external/<ID>/.
#     Status active or superseded: the folder must exist, be a clean git repository,
#     and its HEAD must equal the recorded commit. Status removed: not checked.
#     Column order: id | path | remote | branch | commit | pulled | checked | status
ext_rows=$(awk -F'|' '/^\| ext-/ {
  for (i = 2; i <= 10; i++) { v[i] = $i; gsub(/^ +| +$/, "", v[i]); gsub(/`/, "", v[i]) }
  printf "%s|%s|%s|%s|%s|%s|%s|%s\n", v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9]
}' INDEX.md)

# Only one active version per external repo.
multi=$(printf '%s\n' "$ext_rows" | awk -F'|' '$8 == "active" {
  n = substr($1, 5, length($1) - 13); c[n]++
} END { for (k in c) if (c[k] > 1) print k }')
for n in $multi; do
  problem "$C_EXT_MULTI" "$n"
done

cut30=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)
while IFS='|' read -r id path remote branch commit pulled checked status; do
  [ -n "$id" ] || continue
  echo "$id" | grep -Eq '^ext-[a-z0-9][a-z0-9-]*-[0-9a-f]{8}$' || problem "$C_EXT_BAD_ID" "$id"
  [ "${path%/}" = "external/$id" ] || problem "$C_EXT_BAD_PATH" "$id"
  case "$status" in
    active|superseded|removed) ;;
    *) problem "$C_EXT_BAD_STATUS" "$id" "$status"; continue ;;
  esac
  if printf '%s' "$remote" | grep -Eq '://[^/]*@'; then
    problem "$C_EXT_CRED_REMOTE" "$id"
  fi
  [ "$status" = removed ] && continue
  echo "$commit" | grep -Eq '^[0-9a-f]{40}$' || problem "$C_EXT_BAD_COMMIT" "$id"
  case "$commit" in "${id##*-}"*) ;; *) problem "$C_EXT_ID_MISMATCH" "$id" ;; esac
  [ -n "$branch" ] || problem "$C_EXT_NO_BRANCH" "$id"
  [ -n "$pulled" ] || problem "$C_EXT_NO_PULLED" "$id"
  [ -n "$checked" ] || problem "$C_EXT_NO_CHECKED" "$id"
  if [ ! -d "$path" ]; then
    problem "$C_EXT_NO_DIR" "$id" "$path"
    continue
  fi
  if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    problem "$C_EXT_NOT_GIT" "$id" "$path"
    continue
  fi
  if git -C "$path" config --get remote.origin.url 2>/dev/null | grep -Eq '://[^/]*@'; then
    problem "$C_EXT_CRED_CONFIG" "$id"
  fi
  head_sha=$(git -C "$path" rev-parse HEAD 2>/dev/null)
  [ "$head_sha" = "$commit" ] || problem "$C_EXT_HEAD" "$id" "$head_sha" "$commit"
  [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ] || problem "$C_EXT_DIRTY" "$id"

  if [ "$status" = active ]; then
    if awk -v a="$checked" -v b="$cut30" 'BEGIN { exit !(a < b) }'; then
      hint "$C_EXT_STALE" "$id" "$checked"
    fi
    if [ "$REMOTE_CHECK" = 1 ]; then
      # < /dev/null: ssh reads stdin and would swallow the remaining rows of this loop.
      if ! out=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" git ls-remote "$remote" 2>/dev/null < /dev/null); then
        hint "$C_REMOTE_DOWN" "$id"
        continue
      fi
      # An annotated tag adds a refs/tags/<name>^{} line that points at the commit. Prefer it.
      rhead=$(printf '%s\n' "$out" | awk -v b="$branch" '
        $2 == "refs/heads/" b { plain = $1 }
        $2 == "refs/tags/" b { if (plain == "") plain = $1 }
        $2 == "refs/tags/" b "^{}" { peeled = $1 }
        END { print (peeled != "" ? peeled : plain) }')
      if [ -z "$rhead" ]; then
        hint "$C_REMOTE_NOREF" "$branch" "$id"
      elif [ "$rhead" != "$commit" ]; then
        hint "$C_REMOTE_NEWER" "$branch" "$(printf '%s' "$rhead" | cut -c1-8)" "$(printf '%s' "$commit" | cut -c1-8)" "$id"
      else
        info "$C_REMOTE_SAME" "$branch" "$id"
      fi
    fi
  fi
done <<EOF
$ext_rows
EOF

# 5c. Every folder under external/ must be registered in INDEX.md (catches a pull that was never registered).
for d in $(find external -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | sort); do
  registered "$(basename "$d")" || problem "$C_EXT_UNREG" "$d"
done

# 6. Duplicate content (identical sha256, non-empty files).
#    Two or more live files (outside archive/): problem.
#    A live file plus copies in archive/: hint; the archived copies can go after 30 days without references.
dup_out=$(hash_files \
  | sort \
  | awk '
    {
      p = $0; sub(/^[^ ]+  /, "", p)
      n[$1]++; m[$1, n[$1]] = p
      if (p ~ /^\.\/archive\//) a[$1]++; else l[$1]++
    }
    END {
      for (k in n) {
        if (n[k] < 2 || l[k] == 0) continue
        tag = (l[k] >= 2) ? "P" : "H"
        for (i = 1; i <= n[k]; i++) print tag "\t" substr(k, 1, 12) "\t" m[k, i]
      }
    }' | sort)
if printf '%s\n' "$dup_out" | grep -q '^P'; then
  problem "$C_DUP_ACTIVE"
  printf '%s\n' "$dup_out" | grep '^P' | cut -f2,3 | sed 's/^/    /'
fi
if printf '%s\n' "$dup_out" | grep -q '^H'; then
  hint "$C_DUP_ARCHIVE"
  printf '%s\n' "$dup_out" | grep '^H' | cut -f2,3 | sed 's/^/    /'
fi

# 7. Status: files marked superseded or abandoned must live under archive/
# 8. Staleness: active files not updated for 90 days get a hint
cutoff=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)
for f in $(find . \( -path ./.git -o -path ./node_modules -o -path ./archive -o -path ./external \) -prune -o -name '*.md' -print | sort); do
  st=$(fm "$f" status)
  case "$st" in
    superseded|abandoned)
      problem "$C_NOT_ARCHIVED" "$st" "$f" ;;
    active)
      up=$(fm "$f" updated)
      if [ -n "$up" ] && awk -v a="$up" -v b="$cutoff" 'BEGIN { exit !(a < b) }'; then
        hint "$C_STALE_ACTIVE" "$f" "$up"
      fi ;;
  esac
done

if [ "$fail" -eq 0 ]; then
  printf '%s\n' "$C_PASSED"
fi
exit "$fail"
