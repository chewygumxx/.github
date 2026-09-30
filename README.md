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
file the repository tracks. `cancel-in-progress: false` stops a newer run cancelling the
header sync part-way through its commit.

## Reusable workflows

Triggers, `permissions` and `concurrency` belong to the caller.

| Workflow                    | Runs                                                    | Caller needs                            |
| --------------------------- | ------------------------------------------------------- | --------------------------------------- |
| `standard.yaml`             | all of the below except `lint.yaml`                     | the union of the below                  |
| `commitlint.yaml`           | commitlint over the pushed or pull request commit range | `contents: read`, `pull-requests: read` |
| `sync-header-metadata.yaml` | rewrites file headers and commits them; outputs `sha`   | `contents: write`                       |
| `sync-repo-metadata.yaml`   | applies `.repo-metadata.jsonc` to repository settings   | input `client-id`, secret `private-key` |
| `lint-format.yaml`          | the composite actions below, one job per kind of file   | `contents: read`                        |
| `lint.yaml`                 | the repository's `npm run <script>`, default `check`    | `contents: read`                        |

`commitlint.yaml` and `lint.yaml` run the calling repository's own npm
dependencies and configs, so CI checks the same rules as its local hooks.

## Composite actions

Each lint action runs as steps inside the caller's job, so a repository's own
job can combine them with its own steps.

| Action                      | Checks                                                       |
| --------------------------- | ------------------------------------------------------------ |
| `actions/detect`            | which kinds of file are tracked, as outputs                  |
| `actions/lint-actions`      | workflows with actionlint, and their scripts with shellcheck |
| `actions/lint-shell`        | sh, bash, dash and ksh scripts with shellcheck and shfmt     |
| `actions/lint-zsh`          | zsh scripts with shuck                                       |
| `actions/lint-toml`         | TOML formatting and lint with tombi                          |
| `actions/lint-yaml`         | YAML formatting with prettier, and lint with yamllint        |
| `actions/lint-editorconfig` | files against `.editorconfig`, except indent size            |

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
prettier configuration applies as usual. A `.yamllint` that extends a file from
`node_modules` cannot load here, where nothing is installed; such a repository
lints YAML in its own npm scripts and passes `yaml: false` to `standard.yaml`.

editorconfig-checker skips indent size by default: YAML sequences, Markdown list
continuations and verbatim licence text all break it, and formatters already
own indentation. Pass `editorconfig-args` to change that.

## Versioning

Callers pin a major tag such as `@v1`. Compatible changes move the tag forward,
so every caller picks them up on its next run; breaking changes get a new major
tag, and callers opt in by editing the reference.

The workflows reference the actions and each other at `@v1` as well, so one tag
always names a consistent set. A change to an action is exercised by the
`self-test` workflow before the tag moves.
