#!/bin/sh
# 在新目录中初始化文件命名与更新规范（通用部分）。
# 复制 SPEC.md、模板和工具，生成 INDEX.md 与 .gitignore，创建目录；目录不属于其他 git 仓库时执行 git init（不提交）。
# 已存在的文件一律不覆盖。
# 用法：sh tools/init-workspace.sh [--adapter <名称>] <目标目录>
#   --adapter：运行 adapters/<名称>/install.sh，写入该工具的指令文件和权限配置。

set -u

usage() { echo "用法: sh $0 [--adapter <名称>] <目标目录>"; }

ADAPTER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --adapter)
      if [ $# -lt 2 ]; then echo "--adapter 需要一个名称" >&2; exit 2; fi
      ADAPTER=$2
      shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    --*)
      echo "未知选项: $1" >&2; usage >&2; exit 2 ;;
    *)
      break ;;
  esac
done

if [ $# -lt 1 ]; then
  usage >&2
  exit 2
fi

SPEC_DIR=$(cd "$(dirname "$0")/.." && pwd -P) || exit 2

# 先检查适配层，再创建任何文件。
if [ -n "$ADAPTER" ]; then
  case "$ADAPTER" in
    ""|*[!a-z0-9-]*)
      echo "适配层名称只能含小写字母、数字和连字符: $ADAPTER" >&2; exit 2 ;;
  esac
  if [ ! -f "$SPEC_DIR/adapters/$ADAPTER/install.sh" ]; then
    echo "没有这个适配层: $ADAPTER" >&2
    echo "可用的适配层:" >&2
    for d in "$SPEC_DIR"/adapters/*/; do
      [ -f "${d}install.sh" ] && echo "  $(basename "$d")" >&2
    done
    exit 2
  fi
fi

mkdir -p "$1" || exit 2
TARGET=$(cd "$1" && pwd -P) || exit 2
cd "$TARGET" || exit 2

VERSION=$(tr -d '[:space:]' < "$SPEC_DIR/VERSION")
TODAY=$(date +%Y-%m-%d)

# 复制一个文件。目标已存在则跳过。
put() {
  if [ -e "$2" ]; then
    echo "已存在，跳过: $2"
  else
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    echo "创建: $2"
  fi
}

for d in experiments docs/plans docs/decisions src data/raw data/interim data/processed archive external; do
  mkdir -p "$d"
done

put "$SPEC_DIR/README.md" SPEC.md
for f in "$SPEC_DIR"/templates/*.md; do
  put "$f" "templates/$(basename "$f")"
done
put "$SPEC_DIR/tools/check-workspace.sh" tools/check-workspace.sh
put "$SPEC_DIR/tools/pull-external.sh" tools/pull-external.sh

if [ -e INDEX.md ]; then
  echo "已存在，跳过: INDEX.md"
else
  sed -e "s/{{SPEC_VERSION}}/$VERSION/" -e "s/{{INIT_DATE}}/$TODAY/" "$SPEC_DIR/templates/INDEX.md" > INDEX.md
  echo "创建: INDEX.md"
fi

if [ -e .gitignore ]; then
  echo "已存在，跳过: .gitignore（需包含 external/ 和数据规则，见 SPEC.md 第 8 节）"
else
  cat > .gitignore <<'GITIGNORE'
# 外部仓库是只读副本，版本记录在 INDEX.md 中（SPEC.md 第 12 节）
external/

# 数据和权重不进 git，只保留 MANIFEST.md（SPEC.md 第 8 节）
data/**
!data/**/
!data/**/MANIFEST.md
**/results/**/*.pt
**/results/**/*.bin
**/results/**/*.ckpt
**/results/**/*.safetensors

.DS_Store
GITIGNORE
  echo "创建: .gitignore"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "未安装 git，跳过 git init"
else
  top=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$top" ]; then
    git -C "$TARGET" init -q && echo "已执行 git init（未提交）"
  elif [ "$top" = "$TARGET" ]; then
    echo "已是 git 仓库，跳过 git init"
  else
    echo "目标位于另一个 git 仓库内（$top），跳过 git init，避免嵌套仓库"
  fi
fi

if [ -n "$ADAPTER" ]; then
  echo
  echo "安装适配层: $ADAPTER"
  if ! sh "$SPEC_DIR/adapters/$ADAPTER/install.sh" "$TARGET" "$SPEC_DIR"; then
    echo "适配层安装失败: $ADAPTER" >&2
    exit 1
  fi
fi

echo
echo "初始检查:"
sh tools/check-workspace.sh "$TARGET"
echo
echo "完成。"
