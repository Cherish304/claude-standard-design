---
id: exp-YYYYMMDD-NN
type: experiment
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
superseded_by:
abandoned_reason:
---

# 一句话写清要验证什么

## 目标
要回答的问题，以及判断成立的标准（写出数字阈值）。

## 依赖
- 数据集：`data/processed/...`（见其 MANIFEST.md）
- 基线配置：`configs/...`
- 相关方案：`docs/plans/...`
- 外部仓库：ID、完整 commit（40 位）、拉取时间和核对时间，与 INDEX.md 外部仓库表一致。例：`ext-retrieval`、`<40 位 commit>`、拉取 `2026-11-17T14:30+0800`、核对 `2026-11-20`。实验始终指向这里记录的 commit，外部仓库之后更新也不影响它。

## 变体
| 变体 | 配置文件 | 与基线的差异 |
|---|---|---|
| | | |

## 运行
- 命令：
- 环境（Python、GPU、依赖版本）：
- 运行目录：`results/<run-id>/`

## 结论
状态变为 done 时填写。写出数字和条件，例如"在 qa-eval 上 Recall@5 从 0.71 提升到 0.78，前提是 chunk 为 512 token"。不写"效果更好"这类判断。
