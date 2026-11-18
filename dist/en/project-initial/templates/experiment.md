---
id: exp-YYYYMMDD-NN
type: experiment
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
superseded_by:
abandoned_reason:
---

# One sentence on what this experiment verifies

## Goal
The question to answer, and the criterion for success (give numeric thresholds).

## Depends on
- Dataset: `data/processed/...` (see its MANIFEST.md)
- Baseline config: `configs/...`
- Related plan: `docs/plans/...`
- External repo: ID, full commit (40 characters), pull time and last-checked date, matching the "External repos" table in INDEX.md. Example: `ext-retrieval`, `<40-char commit>`, pulled `2026-11-17T14:30+0800`, checked `2026-11-20`. The experiment always points at the commit recorded here, so later updates of the external repo do not affect it.

## Variants
| Variant | Config file | Difference from baseline |
|---|---|---|
| | | |

## Run
- Command:
- Environment (Python, GPU, dependency versions):
- Run folder: `results/<run-id>/`

## Conclusion
Fill in when the status becomes done. State numbers and conditions, for example "Recall@5 rose from 0.71 to 0.78 on qa-eval, provided the chunk size is 512 tokens". Do not write judgments like "works better".
