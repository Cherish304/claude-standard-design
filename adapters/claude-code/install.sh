#!/bin/sh
# Claude Code 适配层。由 tools/init-workspace.sh --adapter claude-code 调用，也可单独运行。
# 做三件事：
#   1. 把规范块写入 CLAUDE.md。已有则追加到末尾；只有 AGENTS.md 时先导入它。
#   2. 生成 .claude/settings.json（读取、编辑限制，外部仓库指令排除）。已存在则不覆盖。
#   3. 在 .gitignore 中加入本机配置文件。
# 用法：sh install.sh <目标目录> <规范目录>

set -u

if [ $# -ne 2 ]; then
  echo "用法: sh $0 <目标目录> <规范目录>" >&2
  exit 2
fi
TARGET=$1
SPEC_DIR=$2
HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 2
cd "$TARGET" || exit 2

VERSION=$(tr -d '[:space:]' < "$SPEC_DIR/VERSION")
TMP=$(mktemp) || exit 2
trap 'rm -f "$TMP"' EXIT

mkdir -p .claude

# 规范块用块级 HTML 注释标记。Claude Code 注入上下文前会去掉这些注释。
{
  printf '<!-- spec:begin v%s -->\n' "$VERSION"
  cat "$SPEC_DIR/templates/agent-rules.md"
  printf '<!-- spec:end -->\n'
} > "$TMP"

if [ -e CLAUDE.md ]; then
  if grep -q '<!-- spec:begin' CLAUDE.md; then
    echo "CLAUDE.md 已含规范块，未改动"
  else
    { printf '\n'; cat "$TMP"; } >> CLAUDE.md
    echo "CLAUDE.md 已有内容，规范块追加到末尾"
  fi
elif [ -e AGENTS.md ]; then
  # 存在 CLAUDE.md 时 Claude Code 不再读取 AGENTS.md，所以用导入保留它。
  { printf '@AGENTS.md\n\n'; cat "$TMP"; } > CLAUDE.md
  echo "创建: CLAUDE.md（导入已有的 AGENTS.md，并含规范块）"
else
  cp "$TMP" CLAUDE.md
  echo "创建: CLAUDE.md"
fi

if [ -e .claude/settings.json ]; then
  echo "已存在，跳过: .claude/settings.json（请对照 $HERE/settings.json 手动补充缺少的规则）"
else
  cp "$HERE/settings.json" .claude/settings.json
  echo "创建: .claude/settings.json"
fi

touch .gitignore
if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then
  printf '\n' >> .gitignore
fi
for line in '.claude/settings.local.json' 'CLAUDE.local.md'; do
  grep -qxF "$line" .gitignore || printf '%s\n' "$line" >> .gitignore
done
echo ".gitignore 已加入本机配置文件的忽略规则"
