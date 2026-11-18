# project-initial

[English](README.md) · **简体中文**

面向概念验证（POC）工作区的文件命名与更新规范，连同建立它的脚本一起打包成 skill。人和编程 Agent 用它来整理实验、配置、数据集和拉取的仓库。

## 解决的问题

1. **POC 产物散落各处。** 多次实验产生的方案、代码、配置和数据集没有固定位置。规范给每个实验一个目录和固定的命名格式。
2. **过期文件和旧分支误导人和模型。** 每个文件都有状态。过期文件移入 `archive/`，Agent 可以被禁止读取该目录。
3. **没有可维护的索引，重复文件不敢删。** 一份 `INDEX.md` 列出可作为依据的文件。检查工具找出未登记的文件和内容相同的文件，四步流程决定文件何时可以删除。
4. **从 GitLab 等拉取的仓库会过期。** 每个版本放在自己的目录 `external/ext-<名称>-<commit>/`。索引记录拉取时间、完整 commit 和最近核对日期。`--remote` 用 `git ls-remote` 把记录与远端对比，不下载内容。

## 获取

每个包都是自包含的，不读取目录之外的任何内容。

| 语言 | 包 |
|---|---|
| English | `dist/en/project-initial` |
| 简体中文 | `dist/zh-CN/project-initial` |

### 作为 Agent skill 使用

把包复制到所用 Agent 的 skills 目录。Claude Code 读取 `~/.claude/skills/<名称>/SKILL.md`：

```sh
git clone https://github.com/Cherish304/claude-standard-design.git
cp -R claude-standard-design/dist/zh-CN/project-initial ~/.claude/skills/
```

然后让 Agent 用 `project-initial` 初始化某个目录。`SKILL.md` 会告诉它运行什么、检查什么。

### 不用 Agent

```sh
sh dist/zh-CN/project-initial/tools/init-workspace.sh --adapter claude-code ~/work/my-poc
```

省略 `--adapter` 时，只创建与工具无关的部分。

## 初始化会创建什么

| 目标目录中 | 用途 |
|---|---|
| `SPEC.md` | 规范 |
| `INDEX.md` | 唯一总索引，顶部写有规范版本和日期 |
| `templates/` | 实验、数据集清单、索引和 Agent 规则块的模板 |
| `tools/` | 检查工具、拉取工具，以及它们输出的消息 |
| `experiments/`、`docs/`、`data/`、`archive/`、`external/` | 目录结构 |
| `.gitignore` | 数据、权重和 `external/` 不进 git |
| `CLAUDE.md`、`.claude/settings.json` | 仅在使用 `--adapter claude-code` 时创建 |

已存在的文件一律不覆盖。只有目录不在其他仓库内时才执行 `git init`，且不提交。

## 日常使用

```sh
sh tools/check-workspace.sh             # 按规范检查工作区
sh tools/check-workspace.sh --remote    # 同时把外部仓库与远端对比
sh tools/pull-external.sh gitlab-retrieval git@gitlab.example.com:group/retrieval.git main
```

`pull-external.sh` 会输出应加入 `INDEX.md` 的那一行。含用户名或密码的远端地址会被拒绝。

## 适配层

适配层把规范接入某一个 Agent 工具：它的指令文件和权限规则。规范、模板和工具本身不提任何工具名。

| 适配层 | 写入内容 |
|---|---|
| `claude-code` | `CLAUDE.md` 中的规则块，以及禁止读取 `archive/`、禁止编辑 `external/` 的 `.claude/settings.json` |

新增适配层：创建 `src/adapters/<名称>/install.sh`，并为每种语言创建 `src/i18n/<语言>/adapters/<名称>/README.md`。

## 仓库结构

```
src/
  tools/            初始化、检查和拉取脚本（与语言无关）
  adapters/         每个 Agent 工具一个目录
  i18n/<语言>/      SPEC.md、SKILL.md、templates/、messages.sh、适配层 README
scripts/build.sh    构建各语言的包
dist/<语言>/project-initial/   生成的包，不要手动修改
VERSION             规范版本
```

## 参与修改

1. 只改 `src/` 中的文件，不改 `dist/`。
2. 运行 `sh scripts/build.sh`。它先检查各语言的文件、消息键和 `%s` 占位符个数是否一致，再重新构建所有包。
3. 把 `src/` 和 `dist/` 一起提交。

新增语言：把 `src/i18n/en` 复制为 `src/i18n/<代码>`，翻译其中的文件，再构建。`messages.sh` 的键名和 `%s` 占位符的顺序保持不变。

## 环境要求与现状

POSIX `sh`、`git`、`awk`、`sed`、`grep`、`find`，以及 `shasum` 或 `sha256sum`。

- 在 macOS 上用 `sh`（bash 3.2）和 `dash` 测试过。未在 Linux 和 Windows 上测试。
- `claude-code` 适配层的权限规则依据 Claude Code 官方文档编写，没有在真实会话中测试。
- 其他 Agent 工具可以把包当作普通说明文档读取。目前只有 `claude-code` 一个适配层。
