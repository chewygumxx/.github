---
ctime: 2026-10-05
mtime: 2026-10-05
spdx: GPL-3.0-only
title: ".github"
description:
tags:
---

<!--
   -
   - ~chewygumxx/.github.git
   - ::: :/README.md
   -
   -->

# .github

Shared GitHub configuration for `chewygumxx` repositories.

## Standard workflow

Most repositories need only `standard.yaml`. It lints commit messages, syncs
file headers, then runs the generic lint and format checks against the synced
commit, and applies `.repo-metadata.jsonc` on every push to the default branch
or `workflow_dispatch`, refusing a file whose `slug` names another
repository. Each part has a boolean input to switch it off, such as
`metadata-sync: false` for a repository without the metadata App.

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch: {}

permissions:
  contents: write
  pull-requests: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

jobs:
  standard:
    uses: chewygumxx/.github/.github/workflows/standard.yaml@v1
    with:
      metadata-client-id: ${{ vars.METADATA_APP_CLIENT_ID }}
    secrets:
      metadata-private-key: ${{ secrets.METADATA_APP_PRIVATE_KEY }}

  check:
    needs: standard
    if: ${{ !cancelled() }}
    permissions:
      contents: read
    uses: chewygumxx/.github/.github/workflows/lint.yaml@v1
    with:
      ref: ${{ needs.standard.outputs.sha }}
```

Repository-specific jobs such as `check` follow with `needs: standard`. The
`sha` output is the commit the header sync pushed, if any; the `actions`,
`shell`, `zsh`, `toml`, `yaml` and `editorconfig` outputs report which kinds of
file the repository tracks. `cancel-in-progress: false` stops a newer run
cancelling the header sync part-way through its commit.

## Reusable workflows

Triggers, `permissions` and `concurrency` belong to the caller.

| Workflow                    | Runs                                                                                             | Caller needs                            |
| --------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------- |
| `standard.yaml`             | all of the below except `lint.yaml`                                                              | the union of the below                  |
| `commitlint.yaml`           | commitlint over the pushed or pull request commit range                                          | `contents: read`, `pull-requests: read` |
| `sync-header-metadata.yaml` | rewrites file headers and commits them; outputs `sha`                                            | `contents: write`                       |
| `sync-repo-metadata.yaml`   | applies `.repo-metadata.jsonc` to repository settings                                            | input `client-id`, secret `private-key` |
| `lint-format.yaml`          | the composite actions below, one job per kind of file                                            | `contents: read`                        |
| `lint.yaml`                 | the repository's `bun run <script>` or `npm run <script>`, as its lockfile says, default `check` | `contents: read`                        |

`commitlint.yaml` and `lint.yaml` run the calling repository's own
dependencies and configs, installed with Bun when it holds `bun.lock` and npm
when it holds `package-lock.json`, so CI checks the same rules as its local
hooks.

## Composite actions

Each lint action runs as steps inside the caller's job, so a repository's own
job can combine them with its own steps.

| Action                      | Checks                                                       |
| --------------------------- | ------------------------------------------------------------ |
| `actions/detect`            | which kinds of file are tracked, and changed, as outputs     |
| `actions/lint-actions`      | workflows with actionlint, and their scripts with shellcheck |
| `actions/lint-shell`        | sh, bash, dash and ksh scripts with shellcheck and shfmt     |
| `actions/lint-zsh`          | zsh scripts with shuck                                       |
| `actions/lint-toml`         | TOML formatting and lint with tombi                          |
| `actions/lint-yaml`         | YAML formatting with prettier, and lint with yamllint        |
| `actions/lint-editorconfig` | files against `.editorconfig`, except indent size            |
| `actions/lint-emdash`       | tracked text files for em dashes (U+2014)                    |

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: chewygumxx/.github/actions/lint-shell@v1
```

The linters are pinned in `actions/mise.toml` and installed from there, not from
the caller's `mise.toml`, so every repository lints with the same versions.
Dependabot cannot update these pins; bump them by hand or with `mise upgrade`.

Files are sorted into shell families by extension, zsh startup file name,
shebang, then a vim modeline such as `filetype=zsh`, which catches autoloaded
zsh functions with no extension. Symlinks are never linted.

A repository with `.shuck.toml` or `shuck.toml` has chosen shuck for every
shell script: `lint-zsh` then runs shuck over the whole tree, its
`[per-file-shell]` map decides each file's dialect, and `lint-shell` stands
aside, since shfmt and shuck format differently. Shuck's walk skips a file with
no extension and no shebang, such as an autoloaded function, so the detected zsh
scripts are passed to it as well. Without a configuration, shuck sees only the
detected zsh scripts, forced to the zsh dialect.

A repository needs no tombi configuration of its own. `lint-toml` points
`XDG_CONFIG_HOME` at `actions/config`, so tombi takes the house style in
`actions/config/tombi/config.toml`, copied from `chewygumxx/nvim-config`, as its
user-level configuration. A `.tombi.toml`, `tombi.toml`, `.config/tombi.toml` or
`[tool.tombi]` in the repository still takes precedence. Copy the house style to
`~/.config/tombi/config.toml` to have the editor and a local `tombi` agree. Both
tombi commands run `--offline`, so schemas come only from tombi's cache.

Biome does not read YAML, so `lint-yaml` checks it with prettier and yamllint,
as `chewygumxx/nvim-config` does. Neither needs configuring either: prettier's
defaults take indentation from `.editorconfig`, and yamllint is given the house
style in `actions/config/yamllint.yaml` through `YAMLLINT_CONFIG_FILE`, which it
reads only when the repository has no `.yamllint` of its own. A repository's own
prettier configuration applies as usual.

A repository's configuration may come from a shared package in
`node_modules/@chewygumxx`, which these jobs do not install. When the
repository declares one in `package.json` and has not installed it, the action
that needs it fetches it from the npm registry while its linter runs: the
version `bun.lock` resolves, checked against the lock's integrity hash, or the
latest without a lock. `lint-yaml` supplies `prettier-config` and
`yamllint-config`. `lint-shell` passes `shellcheck-config` to shellcheck with
`--rcfile`, and `lint-actions` passes `actionlint-config` to actionlint with
`-config-file`, as the repository's own scripts do, unless it has a
`.shellcheckrc` or `.github/actionlint.yaml` of its own.

editorconfig-checker skips indent size by default: YAML sequences, Markdown list
continuations and verbatim licence text all break it, and formatters already
own indentation. Pass `editorconfig-args` to change that.

## Linting only what changed

`lint-format` checks only what changed since the last commit known to pass. A
pull request is answerable for its own changes, so it is diffed against its
fork point. A push is diffed against the commit of the caller workflow's last
successful push run on its branch: once a lint fails, its files stay in scope
on every later push, whether or not that push touches them, until a run
passes. A lint is skipped when nothing of its kind changed, and otherwise
given only the changed files, except that a change to a file configuring it,
such as `.editorconfig`, `.yamllint.yaml` or `package.json`, checks every file.
`actions/lib/scope.sh` lists those files for each lint, and actionlint checks
every workflow whenever any workflow or action changes.

Everything is checked on `workflow_dispatch`, on the first push of a branch,
under act, and whenever the last passing commit cannot be found: when the
caller's token cannot list its workflow runs, or the commit is gone after a
force push. A public repository's default token can list them; a private one's
needs `actions: read` granted by the caller.

The linters and the house style are pinned by this repository's tag, not by
anything in the caller, so moving `v1` re-checks nothing by itself. Run a
caller's workflow by `workflow_dispatch` to check everything against the new
tag.

A repository using the composite actions directly gets the same from
`actions/detect`, checked out with `fetch-depth: 0`, whose `base` output each
lint action takes as its `base` input; without one it checks every file.

```yaml
steps:
  - uses: actions/checkout@v7
    with:
      fetch-depth: 0
  - id: detect
    uses: chewygumxx/.github/actions/detect@v1
  - if: steps.detect.outputs.shell-scope != 'none'
    uses: chewygumxx/.github/actions/lint-shell@v1
    with:
      base: ${{ steps.detect.outputs.base }}
```

## Running CI locally

`mise run act` runs a repository's CI workflow in Docker with
[act](https://github.com/nektos/act), as a push of `HEAD` against the working
tree, uncommitted changes included. Arguments pass through to act, such as
`-j check` for one job. A repository adds the shared task to its `mise.toml`:

```toml
[settings]
task.remote_no_cache = true

[tasks.act]
description = "Run CI locally with act"
file        = "git::https://github.com/chewygumxx/.github.git//tasks/act?ref=v1"
```

mise would otherwise keep its first copy of the task past any move of `v1`.
The task runs `.github/workflows/ci.yaml`, or the workflow `ACT_WORKFLOW`
names; this repository runs `self-test.yaml` against its own checkout in place
of `v1`. Set `ACT_GITHUB` to a local checkout of this repository to try a
caller against an unreleased change.

`header-sync` and `metadata-sync` write to GitHub, so they skip themselves
under act, whose actor is `nektos/act`. Every other job runs as it would in CI.

## Versioning

Callers pin a major tag such as `@v1`. Compatible changes move the tag forward,
so every caller picks them up on its next run; breaking changes get a new major
tag, and callers opt in by editing the reference.

The workflows reference the actions and each other at `@v1` as well, so one tag
always names a consistent set. A change to an action is exercised by the
`self-test` workflow before the tag moves.

<!-- vim:set expandtab shiftwidth=2 filetype=markdown foldlevel=3: -->
