#!/bin/sh
# 拉取外部仓库的一个版本到 external/<ID>/，并输出应登记到 INDEX.md 的一行。
# 每个版本一个目录，已存在的目录不覆盖。远端地址不得含用户名或密码，凭据走 SSH 或 git 凭据助手。
# 用法：sh tools/pull-external.sh <名称> <远端地址> <分支或标签> [项目根目录]

set -u

if [ $# -lt 3 ]; then
  echo "用法: sh $0 <名称> <远端地址> <分支或标签> [项目根目录]" >&2
  exit 2
fi
NAME=$1
REMOTE=$2
BRANCH=$3
ROOT=${4:-.}

if ! printf '%s\n' "$NAME" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  echo "名称只能含小写字母、数字和连字符，例如 gitlab-retrieval" >&2
  exit 2
fi
if printf '%s' "$REMOTE" | grep -Eq '://[^/]*@'; then
  echo "远端地址含用户名或密码，已拒绝。请改用 SSH 地址或 git 凭据助手，并轮换已泄露的令牌。" >&2
  exit 2
fi

cd "$ROOT" || exit 2
if [ ! -f INDEX.md ]; then
  echo "当前目录没有 INDEX.md，请先运行 init-workspace.sh。" >&2
  exit 2
fi
mkdir -p external || exit 2

TMP=$(mktemp -d "external/.pull-XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT

# 不交互：需要凭据时直接失败，而不是挂起等待输入。
if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" git clone -q --single-branch --branch "$BRANCH" -- "$REMOTE" "$TMP/repo"; then
  echo "克隆失败。请检查远端地址、分支或标签名、访问权限和网络。" >&2
  exit 1
fi

COMMIT=$(git -C "$TMP/repo" rev-parse HEAD) || exit 1
SHORT=$(printf '%s' "$COMMIT" | cut -c1-8)
ID="ext-${NAME}-${SHORT}"
DEST="external/${ID}"

if [ -e "$DEST" ]; then
  echo "已存在 ${DEST}，该 commit 已拉取过，未覆盖。" >&2
  exit 1
fi
mv "$TMP/repo" "$DEST" || exit 1

NOW=$(date +%Y-%m-%dT%H:%M%z)
TODAY=$(date +%Y-%m-%d)
echo "已拉取: ${DEST}"
echo
echo "请在 INDEX.md 的「外部仓库」表中加入下面一行（与拉取在同一次操作中完成）:"
echo
echo "| ${ID} | \`${DEST}/\` | ${REMOTE} | ${BRANCH} | ${COMMIT} | ${NOW} | ${TODAY} | active | |"
