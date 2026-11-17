#!/bin/sh
# 把规范仓库中的框架、工具和适配层复制进 skill 目录，使 skill 自包含。
# skill 目录的布局与本仓库根目录相同，另有 SKILL.md（来源是 skill/SKILL.md）。
# 每次运行都会替换 skill 中的 README.md、VERSION、SKILL.md、templates/、tools/、adapters/。
# 用法：sh tools/build-skill.sh <skill 目录>
# 例：  sh tools/build-skill.sh ~/.claude/skills/project-initial

set -eu

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "用法: sh $0 <skill 目录>" >&2
  exit 2
fi

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
mkdir -p "$1"
DEST=$(cd "$1" && pwd -P)

if [ "$DEST" = "$REPO" ] || [ "$DEST" = "/" ]; then
  echo "拒绝写入: $DEST" >&2
  exit 2
fi

rm -rf "$DEST/templates" "$DEST/tools" "$DEST/adapters"
mkdir -p "$DEST/templates" "$DEST/tools"

cp "$REPO/README.md" "$REPO/VERSION" "$REPO/skill/SKILL.md" "$DEST/"
cp "$REPO"/templates/*.md "$DEST/templates/"
for t in init-workspace.sh check-workspace.sh pull-external.sh; do
  cp "$REPO/tools/$t" "$DEST/tools/"
done
cp -R "$REPO/adapters" "$DEST/adapters"
find "$DEST" -name .DS_Store -exec rm -f {} +

echo "已写入 skill: $DEST"
find "$DEST" -type f | sort | sed "s#^$DEST/#  #"
