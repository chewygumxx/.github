# .github

Shared GitHub configuration for `chewygumxx` repositories.

## Reusable workflows

Each workflow runs against the calling repository's own `mise.toml`,
`package.json` and configs, so CI checks the same rules as that repository's
local hooks. Triggers, `permissions` and `concurrency` belong to the caller.

| Workflow                    | Runs                                                    | Caller needs                            |
| --------------------------- | ------------------------------------------------------- | --------------------------------------- |
| `lint.yaml`                 | `npm run <script>` (input `script`, default `check`)    | `contents: read`                        |
| `commitlint.yaml`           | commitlint over the pushed or pull request commit range | `contents: read`, `pull-requests: read` |
| `sync-header-metadata.yaml` | rewrites file headers and commits them                  | `contents: write`                       |
| `sync-repo-metadata.yaml`   | applies `.repo-metadata.jsonc` to repository settings   | input `client-id`, secret `private-key` |

```yaml
jobs:
    check:
        uses: chewygumxx/.github/.github/workflows/lint.yaml@v1
```

## Versioning

Callers pin a major tag such as `@v1`. Compatible changes move the tag forward,
so every caller picks them up on its next run; breaking changes get a new major
tag, and callers opt in by editing the reference.
