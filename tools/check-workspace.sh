#!/bin/sh
# 检查工作区是否符合文件命名与更新规范（项目中为 SPEC.md，规范仓库中为 README.md）。
# 默认只读本地文件：不修改、不删除任何文件，不访问网络。
# --remote：对状态为 active 的外部仓库执行 git ls-remote，只读取远端引用，判断远端是否有新提交。
# 有问题时退出码为 1，提示不影响退出码。
# 用法：sh tools/check-workspace.sh [--remote] [项目根目录]

set -u
set -f          # 关闭通配符展开，文件名中的 [ * ? 不会被误展开

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

problem() { echo "[问题] $*"; fail=1; }
hint() { echo "[提示] $*"; }

# 列出参与内容重复检查的非空文件的 sha256。
# external/ 是外部仓库副本，templates/ 是模板，二者不参与检查。
hash_files() {
  if command -v sha256sum >/dev/null 2>&1; then
    find . \( -path ./.git -o -path ./node_modules -o -path ./external -o -path ./templates \) -prune -o -type f ! -empty ! -name .DS_Store -exec sha256sum {} +
  else
    find . \( -path ./.git -o -path ./node_modules -o -path ./external -o -path ./templates \) -prune -o -type f ! -empty ! -name .DS_Store -exec shasum -a 256 {} +
  fi
}

# 读取文件开头 frontmatter 中某个字段的值。没有 frontmatter 时返回空。
fm() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    index($0, key ":") == 1 { sub(/^[^:]*: */, ""); sub(/ *#.*$/, ""); print; exit }
  ' "$1"
}

# 名称是否出现在 INDEX.md 中（子串匹配）。
registered() { grep -qF "$1" INDEX.md; }

if [ ! -f INDEX.md ]; then
  problem "缺少 INDEX.md"
  exit 1
fi

# 1. 文件名：禁用词、副本后缀、空白字符（archive/、data/raw/、external/ 不检查）
for p in $(find . \( -path ./.git -o -path ./node_modules -o -path ./archive -o -path ./data/raw -o -path ./external \) -prune -o -print \
  | grep -E '(^|[-_./])(final|new|latest|copy|old|bak|backup|tmp|test[0-9]+|v[0-9]+)([-_.]|$)|\([0-9]+\)|[[:space:]]|最终|副本|新版|旧版'); do
  problem "文件名不合规: $p"
done

# 2. 实验目录：命名格式、说明文件及其 frontmatter、登记到 INDEX.md
for d in $(find experiments -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
  name=$(basename "$d")
  echo "$name" | grep -Eq '^exp-[0-9]{8}-[0-9]{2}-[a-z0-9][a-z0-9-]*$' || problem "实验目录名不合规: $d"
  if [ -f "$d/README.md" ]; then
    [ -n "$(fm "$d/README.md" status)" ] || problem "实验说明缺少 frontmatter 的 status 字段: $d/README.md"
  else
    problem "实验缺少 README.md: $d"
  fi
  registered "$name" || problem "实验未登记到 INDEX.md: $d"
done

# 3. 方案与决策：命名格式、frontmatter 的 status、登记到 INDEX.md
for f in $(find docs/plans -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort); do
  b=$(basename "$f")
  echo "$b" | grep -Eq '^[0-9]{8}-[a-z0-9][a-z0-9-]*\.md$' || problem "方案文件名不合规: $f"
  [ -n "$(fm "$f" status)" ] || problem "方案缺少 frontmatter 的 status 字段: $f"
  registered "$b" || problem "方案未登记到 INDEX.md: $f"
done
for f in $(find docs/decisions -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort); do
  b=$(basename "$f")
  echo "$b" | grep -Eq '^[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' || problem "决策文件名不合规: $f"
  [ -n "$(fm "$f" status)" ] || problem "决策缺少 frontmatter 的 status 字段: $f"
  registered "$b" || problem "决策未登记到 INDEX.md: $f"
done

# 4. 数据集：必须有 MANIFEST.md，并登记到 INDEX.md
for d in $(find data/processed -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
  [ -f "$d/MANIFEST.md" ] || problem "数据集缺少 MANIFEST.md: $d"
  registered "$(basename "$d")" || problem "数据集未登记到 INDEX.md: $d"
done

# 5. INDEX.md 中用反引号标出的路径必须存在（状态为 removed 的行除外）
for p in $(grep -v '| removed |' INDEX.md | grep -oE '`[^`]*(/|\.md)[^`]*`' | tr -d '`' | sort -u); do
  [ -e "$p" ] || problem "INDEX.md 指向不存在的路径: $p"
done

# 5b. 外部仓库：INDEX.md 中 ID 以 ext- 开头的行。
#     ID 为 ext-<名称>-<commit 前 8 位>，本地路径为 external/<ID>/。
#     状态 active 或 superseded：目录须存在、是干净的 git 仓库，HEAD 与记录的 commit 一致。
#     状态 removed：目录已删除，不检查。
#     字段顺序：id | 路径 | 远端 | 分支 | commit | 拉取时间 | 核对时间 | 状态
ext_rows=$(awk -F'|' '/^\| ext-/ {
  for (i = 2; i <= 10; i++) { v[i] = $i; gsub(/^ +| +$/, "", v[i]); gsub(/`/, "", v[i]) }
  printf "%s|%s|%s|%s|%s|%s|%s|%s\n", v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9]
}' INDEX.md)

# 同一个外部仓库只能有一个 active 版本。
multi=$(printf '%s\n' "$ext_rows" | awk -F'|' '$8 == "active" {
  n = substr($1, 5, length($1) - 13); c[n]++
} END { for (k in c) if (c[k] > 1) print k }')
for n in $multi; do
  problem "同一外部仓库有多个 active 版本，应只保留一个，其余改为 superseded: ${n}"
done

cut30=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)
while IFS='|' read -r id path remote branch commit pulled checked status; do
  [ -n "$id" ] || continue
  echo "$id" | grep -Eq '^ext-[a-z0-9][a-z0-9-]*-[0-9a-f]{8}$' || problem "外部仓库 ID 应为 ext-<名称>-<commit 前 8 位>: $id"
  [ "${path%/}" = "external/$id" ] || problem "外部仓库本地路径应为 external/$id/: $id"
  case "$status" in
    active|superseded|removed) ;;
    *) problem "外部仓库状态不合法（应为 active、superseded 或 removed）: $id $status"; continue ;;
  esac
  if printf '%s' "$remote" | grep -Eq '://[^/]*@'; then
    problem "外部仓库远端地址含凭据，请去掉用户名和密码，并轮换已泄露的令牌: $id"
  fi
  [ "$status" = removed ] && continue
  echo "$commit" | grep -Eq '^[0-9a-f]{40}$' || problem "外部仓库 commit 应为完整 40 位: $id"
  case "$commit" in "${id##*-}"*) ;; *) problem "外部仓库 ID 末尾与 commit 不一致: $id" ;; esac
  [ -n "$branch" ] || problem "外部仓库缺少分支或标签: $id"
  [ -n "$pulled" ] || problem "外部仓库缺少拉取时间: $id"
  [ -n "$checked" ] || problem "外部仓库缺少核对时间: $id"
  if [ ! -d "$path" ]; then
    problem "外部仓库目录不存在: $id $path"
    continue
  fi
  if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    problem "外部仓库不是 git 仓库: $id $path"
    continue
  fi
  if git -C "$path" config --get remote.origin.url 2>/dev/null | grep -Eq '://[^/]*@'; then
    problem "外部仓库的 .git/config 中远端地址含凭据，请改为不含凭据的地址并轮换令牌: $id"
  fi
  head_sha=$(git -C "$path" rev-parse HEAD 2>/dev/null)
  [ "$head_sha" = "$commit" ] || problem "外部仓库 HEAD 与 INDEX.md 记录不一致: $id 本地 $head_sha，记录 $commit"
  [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ] || problem "外部仓库有未提交改动或未跟踪文件（应只读）: $id"

  if [ "$status" = active ]; then
    if awk -v a="$checked" -v b="$cut30" 'BEGIN { exit !(a < b) }'; then
      hint "外部仓库核对时间超过 30 天，请运行 --remote 核对远端（SPEC.md 第 12.4 节）: $id（核对时间: $checked）"
    fi
    if [ "$REMOTE_CHECK" = 1 ]; then
      # < /dev/null：ssh 会读标准输入，不隔离的话会吃掉循环里后面几行记录。
      if ! out=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" git ls-remote "$remote" 2>/dev/null < /dev/null); then
        hint "无法访问远端，未能核对（网络、权限或地址有误）: $id"
        continue
      fi
      # 带注释的标签会多出一行 refs/tags/<名称>^{}，它指向 commit，优先使用。
      rhead=$(printf '%s\n' "$out" | awk -v b="$branch" '
        $2 == "refs/heads/" b { plain = $1 }
        $2 == "refs/tags/" b { if (plain == "") plain = $1 }
        $2 == "refs/tags/" b "^{}" { peeled = $1 }
        END { print (peeled != "" ? peeled : plain) }')
      if [ -z "$rhead" ]; then
        hint "远端找不到分支或标签 ${branch}，请确认是否改名或删除，并记在 INDEX.md 说明列: $id"
      elif [ "$rhead" != "$commit" ]; then
        hint "远端 ${branch} 已有新提交 $(printf '%s' "$rhead" | cut -c1-8)，记录的是 $(printf '%s' "$commit" | cut -c1-8)。更新见 SPEC.md 第 12.5 节: $id"
      else
        echo "[核对] 远端 ${branch} 仍是记录的 commit，可把核对时间更新为今天: $id"
      fi
    fi
  fi
done <<EOF
$ext_rows
EOF

# 5c. external/ 下每个目录都必须登记到 INDEX.md（拉取后忘记登记，会在这里发现）。
for d in $(find external -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | sort); do
  registered "$(basename "$d")" || problem "external/ 下的目录未登记到 INDEX.md: $d"
done

# 6. 内容重复（sha256 相同的非空文件）。
#    两份以上现行文件（不在 archive/ 中）重复：问题。
#    现行文件与 archive/ 中的副本重复：提示，满 30 天且无引用后可删副本。
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
  problem "存在内容相同的现行文件（两份以上且不在 archive/ 中）:"
  printf '%s\n' "$dup_out" | grep '^P' | cut -f2,3 | sed 's/^/    /'
fi
if printf '%s\n' "$dup_out" | grep -q '^H'; then
  hint "archive/ 中有与现行文件内容相同的副本。满 30 天且无引用后可删除:"
  printf '%s\n' "$dup_out" | grep '^H' | cut -f2,3 | sed 's/^/    /'
fi

# 7. 状态：superseded 和 abandoned 的文件必须在 archive/ 中
# 8. 陈旧：active 超过 90 天未更新，提示复核
cutoff=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)
for f in $(find . \( -path ./.git -o -path ./node_modules -o -path ./archive -o -path ./external \) -prune -o -name '*.md' -print | sort); do
  st=$(fm "$f" status)
  case "$st" in
    superseded|abandoned)
      problem "状态为 ${st}，但文件不在 archive/: ${f}" ;;
    active)
      up=$(fm "$f" updated)
      if [ -n "$up" ] && awk -v a="$up" -v b="$cutoff" 'BEGIN { exit !(a < b) }'; then
        hint "状态为 active，但超过 90 天未更新，请复核: ${f}（updated: ${up}）"
      fi ;;
  esac
done

if [ "$fail" -eq 0 ]; then
  echo "检查通过"
fi
exit "$fail"
