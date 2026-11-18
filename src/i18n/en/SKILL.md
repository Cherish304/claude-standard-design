---
name: project-initial
description: Set up a file naming and update spec in a new or existing project folder, including SPEC.md, INDEX.md, experiment and plan templates, a consistency check tool, an external repo pull tool, and an optional adapter for an agent tool. Use it when the user asks to initialize a project, set up a workspace framework, apply the file spec, tidy experiment folders or copies of external repos, or before starting POC work in a new folder.
---

# project-initial

This skill puts the file naming and update spec into a target folder. Every file, template and script it needs is inside this skill folder; nothing outside it is read at run time.

`<skill>` below means the folder that holds this file. All paths are relative to it.

## Contents

| Path | What it is |
|---|---|
| `SPEC.md` | The spec. The init script copies it to the target folder as `SPEC.md` |
| `VERSION` | Spec version |
| `templates/` | Templates for INDEX, an experiment, a dataset manifest and the agent rules block |
| `tools/init-workspace.sh` | The init script |
| `tools/check-workspace.sh` | Consistency check. With `--remote` it checks whether external repos have newer commits |
| `tools/pull-external.sh` | Pulls one version of an external repo |
| `tools/messages.sh` | The messages the tools print, in this skill's language |
| `adapters/<name>/` | One adapter per agent tool. At the moment: `claude-code` |

## Steps

1. **Find the target folder.** Use the path the user gives. If there is none, use the current working directory and say which path it is.
2. **Look at what is there.** Run `ls -A <target>`.
   - Empty or new folder: initialize it.
   - Existing files: the scripts never overwrite an existing file. When a `.gitignore`, an instruction file or a permission file already exists, the adapter only tells you which rules to add by hand. When there is a lot of untidy content, do not work on it directly: tell the user to migrate it as described in section 11 of `SPEC.md` and let them decide.
   - Target inside another git repository: the script skips `git init`. That is normal; tell the user.
3. **Choose an adapter.** Run `ls <skill>/adapters/`. Pick the one that matches the tool you are running in and enable it with `--adapter <name>`. If none matches, leave the option out. Without it the framework is still generated; only the instruction file and permission settings of that tool are missing.
4. **Run the init script:**

   ```sh
   sh <skill>/tools/init-workspace.sh [--adapter <name>] "<target>"
   ```

   The script creates the target folder when it does not exist.
5. **Read the output:**
   - `Created:` marks new files, `Already exists, skipped:` marks files left unchanged.
   - A message that asks you to add something by hand names the file to compare with. Do what it says.
   - On a non-zero exit code, report the error as printed. Do not guess at the cause and work around it.
6. **Verify:**
   - The target has `SPEC.md`, `INDEX.md`, `templates/` and `tools/`.
   - The initial check prints `Check passed`. If it prints `[problem]` lines, explain each one. Do not delete or rewrite the user's files.
   - If you used an adapter, look at the files it wrote; it is described in `<skill>/adapters/<name>/README.md`.
   - If you used no adapter, tell the user that the rules block is in `templates/agent-rules.md` and has to be put into the project instruction file of their tool before an agent reads it.
7. **Tell the user what comes next**, and only this:
   - Existing files must be registered in `INDEX.md` or migrated.
   - Use `tools/pull-external.sh` for external repos and add the row it prints to `INDEX.md`.
   - The scripts commit nothing. Committing is the user's decision.

## What this skill does not do

- It does not overwrite or delete any file.
- It does not commit, push or pull a remote repo. A pull needs an address and a branch from the user.
- It does not change files inside `<skill>`.
- It does not write outside the target folder.

## Version

`<skill>/VERSION` is the version of the framework in this skill. The top of the target's `INDEX.md` records the version used at initialization. When they differ, tell the user, who decides whether to merge `SPEC.md` and the templates by hand. The init script never overwrites existing files.
