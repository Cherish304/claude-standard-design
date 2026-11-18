# 适配层：Claude Code

这一层把通用规范接入 Claude Code。通用部分（`SPEC.md`、`templates/`、`tools/`）不提具体工具。换用其他工具时，在 `adapters/<工具名>/` 下新建 `install.sh`，接入该工具的指令文件和权限规则即可。

## 安装

新目录：

```sh
sh tools/init-workspace.sh --adapter claude-code <目标目录>
```

已初始化的目录，只补适配层：

```sh
sh <包目录>/adapters/claude-code/install.sh <目标目录> <包目录>
```

## 写入的内容

| 文件 | 内容 |
|---|---|
| `CLAUDE.md` | `templates/agent-rules.md` 的规范块，用 `<!-- spec:begin -->` 和 `<!-- spec:end -->` 包住。已有 CLAUDE.md 时追加到末尾；已含规范块则不动。只有 AGENTS.md 时，CLAUDE.md 先写 `@AGENTS.md` 导入它。 |
| `.claude/settings.json` | 下面的读取、编辑和排除规则。已存在则不覆盖，脚本提示需要补充的内容。 |
| `.gitignore` | 追加 `.claude/settings.local.json` 和 `CLAUDE.local.md`，两者只属于本机。 |

## settings.json 的各项

- `"Read(./archive/**)"`：Read 拒绝读取 `archive/`，Edit 和 Write 也不能修改那里的文件。Grep 和 Glob 只是尽力应用。
- `"Edit(./external/**)"`：禁止修改 `external/` 中的文件。
- `"claudeMdExcludes": ["**/external/ext-*/**"]`：不加载外部仓库里的 CLAUDE.md 和 AGENTS.md。模式按绝对路径匹配。用 `ext-*` 限定，避免项目上层有一个叫 `external` 的目录时，误排除本项目的 CLAUDE.md。

限制：`grep -r pattern .` 这类不指明文件名的 Bash 命令，以及 Python、Node 脚本内部打开文件的操作，不受读取规则约束。需要强制阻止时，启用 Claude Code 的沙盒。

## 依据

| 问题 | 来源 | 结论 |
|---|---|---|
| 指令文件长度 | [Claude Code 记忆文档](https://code.claude.com/docs/en/memory) | 每个 CLAUDE.md 建议控制在 200 行以内。越长遵守率越低。 |
| HTML 注释 | 同一文档 | 块级 HTML 注释在注入上下文前会被去掉，代码块内的注释保留。 |
| 导入 | 同一文档 | `@path` 导入的文件会展开并加载。相对路径相对于含导入的文件解析。最多 4 层。 |
| AGENTS.md | 同一文档 | 只有目录链上没有 CLAUDE.md 时才读取 AGENTS.md。需要 Claude Code v2.1.277 或更高版本。 |
| 排除规则 | 同一文档 | `claudeMdExcludes` 可在任一设置层级排除指定路径的 CLAUDE.md。 |
| 读取和编辑规则 | [Claude Code 权限文档](https://code.claude.com/docs/en/permissions) | `Read(path)` 和 `Edit(path)` 拒绝规则会阻止内置文件工具访问匹配路径。Grep 和 Glob 只是尽力应用。 |

## 未验证的部分

- 两个设置项在真实 Claude Code 会话中是否按预期拦截，只依据官方文档，没有在会话中测试。
- `**/external/ext-*/**` 的匹配结果没有实测。
