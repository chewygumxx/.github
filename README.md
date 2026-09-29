# .github

Shared GitHub configuration for `chewygumxx` repositories.

## Standard workflow

Most repositories need only `standard.yaml`. It lints commit messages, syncs
file headers, then runs the generic lint and format checks against the synced
commit, and applies `.repo-metadata.jsonc` on every push to the default branch
or `workflow_dispatch`. Each part has a boolean input to switch it off, such as
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
`shell`, `toml` and `editorconfig` outputs report which kinds of file the
repository tracks. `cancel-in-progress: false` stops a newer run cancelling the
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
| `actions/lint-toml`         | TOML formatting with taplo                                   |
| `actions/lint-editorconfig` | files against `.editorconfig`, except indent size            |

```yaml
steps:
    - uses: actions/checkout@v7
    - uses: chewygumxx/.github/actions/lint-shell@v1
```

The linters are pinned in `actions/mise.toml` and installed from there, not from
the caller's `mise.toml`, so every repository lints with the same versions.
Dependabot cannot update these pins; bump them by hand or with `mise upgrade`.

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
