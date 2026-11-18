# Adapter: Claude Code

This layer connects the tool-neutral spec to Claude Code. The neutral part (`SPEC.md`, `templates/`, `tools/`) names no tool. To support another tool, add `adapters/<tool-name>/install.sh` that wires in that tool's instruction file and permission rules.

## Install

New folder:

```sh
sh tools/init-workspace.sh --adapter claude-code <target-dir>
```

A folder that is already initialized, adapter only:

```sh
sh <package-dir>/adapters/claude-code/install.sh <target-dir> <package-dir>
```

## What it writes

| File | Content |
|---|---|
| `CLAUDE.md` | The block from `templates/agent-rules.md`, wrapped in `<!-- spec:begin -->` and `<!-- spec:end -->`. Appended to the end of an existing CLAUDE.md; left alone when the block is already there. When only AGENTS.md exists, the new CLAUDE.md starts with `@AGENTS.md` to import it. |
| `.claude/settings.json` | The read, edit and exclusion rules below. An existing file is not overwritten; the script says what to add. |
| `.gitignore` | Adds `.claude/settings.local.json` and `CLAUDE.local.md`, which belong to one machine only. |

## What settings.json contains

- `"Read(./archive/**)"`: Read refuses to read `archive/`, and Edit and Write cannot change files there. Grep and Glob apply it on a best-effort basis.
- `"Edit(./external/**)"`: files in `external/` cannot be changed.
- `"claudeMdExcludes": ["**/external/ext-*/**"]`: CLAUDE.md and AGENTS.md files inside external repos are not loaded. Patterns match absolute paths. The `ext-*` part keeps a folder named `external` somewhere above the project from excluding this project's own CLAUDE.md.

Limit: a Bash command such as `grep -r pattern .` that does not name the file, and a Python or Node script that opens files itself, are not covered by the read rules. To enforce it for every process, turn on the Claude Code sandbox.

## Sources

| Question | Source | Finding |
|---|---|---|
| Length of instruction files | [Claude Code memory docs](https://code.claude.com/docs/en/memory) | Keep each CLAUDE.md under about 200 lines. Longer files are followed less reliably. |
| HTML comments | Same page | Block-level HTML comments are stripped before the file is injected into context. Comments inside code blocks stay. |
| Imports | Same page | A file imported with `@path` is expanded and loaded. Relative paths resolve against the file that contains the import. Up to 4 levels. |
| AGENTS.md | Same page | AGENTS.md is read only when there is no CLAUDE.md in the directory chain. Needs Claude Code v2.1.277 or later. |
| Exclusions | Same page | `claudeMdExcludes` excludes CLAUDE.md files by path at any settings level. |
| Read and edit rules | [Claude Code permissions docs](https://code.claude.com/docs/en/permissions) | `Read(path)` and `Edit(path)` deny rules stop the built-in file tools from touching matching paths. Grep and Glob apply them on a best-effort basis. |

## Not verified

- Whether the two settings block as expected in a real Claude Code session is based on the official docs only. It was not tested in a session.
- The match of `**/external/ext-*/**` was not tested.
