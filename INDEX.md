# 索引

| ID | 路径 | 状态 | 说明 |
|---|---|---|---|
| spec | `README.md` | active | 文件命名与更新规范（正文，初始化时复制为项目的 SPEC.md） |
| version | `VERSION` | active | 规范版本号，初始化脚本读取它 |
| tpl-index | `templates/INDEX.md` | active | 索引模板 |
| tpl-experiment | `templates/experiment.md` | active | 实验说明模板 |
| tpl-manifest | `templates/MANIFEST.md` | active | 数据集清单模板 |
| tpl-rules | `templates/agent-rules.md` | active | 给 Agent 的规则块，与工具无关 |
| tool-check | `tools/check-workspace.sh` | active | 工作区一致性检查 |
| tool-pull | `tools/pull-external.sh` | active | 拉取外部仓库版本 |
| tool-init | `tools/init-workspace.sh` | active | 新目录初始化，可选适配层 |
| skill-source | `skill/SKILL.md` | active | project-initial skill 的说明，构建时复制到 skill 根目录 |
| tool-build-skill | `tools/build-skill.sh` | active | 把框架、工具和适配层复制进 skill 目录 |
| adapter-claude | `adapters/claude-code/` | active | Claude Code 适配层，说明见其 README |
