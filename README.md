# project-initial

**English** · [简体中文](README.zh-CN.md)

A file naming and update spec for proof-of-concept (POC) workspaces, packaged as a skill together with the scripts that set it up. People and coding agents use it to keep experiments, configs, datasets and pulled repos in order.

## Problems it addresses

1. **POC output ends up everywhere.** Plans, code, configs and datasets from repeated experiments have no fixed place. The spec gives each experiment one folder and fixed naming patterns.
2. **Expired files and old branches mislead people and models.** Every file carries a status. Expired files move to `archive/`, which an agent can be blocked from reading.
3. **No index you can maintain, so duplicates are never deleted.** One `INDEX.md` lists what counts as evidence. A check tool finds unregistered files and files with identical content, and a four-step routine decides when a file may go.
4. **Repos pulled from GitLab and similar go stale.** Each version sits in its own folder, `external/ext-<name>-<commit>/`. The index records the pull time, the full commit and the date it was last checked. `--remote` compares the record with the remote using `git ls-remote`, which downloads nothing.

## Get it

Each package is self-contained. Nothing outside its folder is read.

| Language | Package |
|---|---|
| English | `dist/en/project-initial` |
| 简体中文 | `dist/zh-CN/project-initial` |

### As an agent skill

Copy a package into the skills folder of your agent. Claude Code reads `~/.claude/skills/<name>/SKILL.md`:

```sh
git clone https://github.com/Cherish304/claude-standard-design.git
cp -R claude-standard-design/dist/en/project-initial ~/.claude/skills/
```

Then ask the agent to initialize a folder with `project-initial`. `SKILL.md` tells it what to run and what to check.

### Without an agent

```sh
sh dist/en/project-initial/tools/init-workspace.sh --adapter claude-code ~/work/my-poc
```

Leave out `--adapter` to create only the tool-neutral part.

## What initialization creates

| In the target folder | Purpose |
|---|---|
| `SPEC.md` | The spec |
| `INDEX.md` | The one index, with the spec version and the date at the top |
| `templates/` | Experiment, dataset manifest, index and agent-rules templates |
| `tools/` | Check tool, pull tool, and the messages they print |
| `experiments/`, `docs/`, `data/`, `archive/`, `external/` | The folder layout |
| `.gitignore` | Keeps data, weights and `external/` out of git |
| `CLAUDE.md`, `.claude/settings.json` | Only with `--adapter claude-code` |

Existing files are never overwritten. `git init` runs only when the folder is not already inside a repository, and nothing is committed.

## Day to day

```sh
sh tools/check-workspace.sh             # check the workspace against the spec
sh tools/check-workspace.sh --remote    # also compare external repos with their remotes
sh tools/pull-external.sh gitlab-retrieval git@gitlab.example.com:group/retrieval.git main
```

`pull-external.sh` prints the row to add to `INDEX.md`. Remote URLs that contain a user name or password are rejected.

## Adapters

An adapter connects the spec to one agent tool: its instruction file and its permission rules. The spec, the templates and the tools name no tool.

| Adapter | Writes |
|---|---|
| `claude-code` | A rules block in `CLAUDE.md`, and `.claude/settings.json` that denies reading `archive/` and editing `external/` |

To add one, create `src/adapters/<name>/install.sh` and, per language, `src/i18n/<lang>/adapters/<name>/README.md`.

## Repository layout

```
src/
  tools/            init, check and pull scripts (language-neutral)
  adapters/         one folder per agent tool
  i18n/<lang>/      SPEC.md, SKILL.md, templates/, messages.sh, adapter READMEs
scripts/build.sh    builds the packages
dist/<lang>/project-initial/   generated packages. Do not edit them
VERSION             spec version
```

## Contributing

1. Edit files in `src/`, never in `dist/`.
2. Run `sh scripts/build.sh`. It first checks that every language has the same files, the same message keys and the same number of `%s` placeholders, then rebuilds every package.
3. Commit `src/` and `dist/` together.

To add a language, copy `src/i18n/en` to `src/i18n/<code>`, translate the files, and build. Keep the keys of `messages.sh` and the order of the `%s` placeholders unchanged.

## Requirements and status

POSIX `sh`, `git`, `awk`, `sed`, `grep`, `find`, and `shasum` or `sha256sum`.

- Tested on macOS with `sh` (bash 3.2) and `dash`. Not tested on Linux or Windows.
- The permission rules of the `claude-code` adapter follow the official Claude Code documentation. They were not tested in a live session.
- Other agent tools can read a package as plain instructions. Only the `claude-code` adapter exists so far.
