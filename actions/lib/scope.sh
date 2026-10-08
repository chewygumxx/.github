#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/scope.sh
#
#

# Usage: LINT_BASE=COMMIT scope.sh KIND
#
# Prints how much of one kind of file a lint must check against LINT_BASE,
# the last commit known to pass (see base.sh):
#
#   all      every file: LINT_BASE is empty or missing, or a file that
#            configures the linter changed, which can break any file
#   changed  only the files changed since LINT_BASE; tracked.sh lists them
#   none     nothing of this kind changed
#
# KIND is actions, shell, zsh, toml, yaml, editorconfig or emdash. Each lint
# is per file, so a file identical to its passing state still passes, given
# the same configuration. The configuration is what this list names; the
# linters and house style pinned by this repository's tag are not, so after
# moving the tag, run the caller's workflow by workflow_dispatch to check
# everything.

set -euo pipefail

kind=$1
lib=$(cd "$(dirname "$0")" && pwd)

if [[ -z ${LINT_BASE-} ]]; then
    echo all
    exit 0
fi
if ! git cat-file -e "$LINT_BASE^{commit}" 2>/dev/null; then
    echo "::notice title=Full lint::$LINT_BASE is not in the checkout; check out with fetch-depth: 0 to lint only changes" >&2
    echo all
    exit 0
fi

shuck_configured() { [[ -n $(git ls-files -- .shuck.toml shuck.toml) ]]; }

# Each kind: the files configuring its linter, then a command listing its
# files. Shared configurations come from package.json, at the version
# bun.lock resolves (see shared-config.sh).
case $kind in
actions)
    # actionlint checks a workflow against the workflows and actions it
    # calls, so any change to one checks them all.
    config=(.github/workflows .github/actionlint.yaml .github/actionlint.yml
        action.yml action.yaml '*/action.yml' '*/action.yaml'
        .shellcheckrc shellcheckrc package.json bun.lock)
    list=("$lib/tracked.sh" '.github/workflows/*.yml' '.github/workflows/*.yaml')
    ;;
shell)
    # shfmt takes its style from .editorconfig.
    config=(.shellcheckrc shellcheckrc .editorconfig '*/.editorconfig'
        package.json bun.lock)
    list=("$lib/filetype.sh" sh)
    ;;
zsh)
    config=(.shuck.toml shuck.toml)
    list=("$lib/filetype.sh" zsh)
    ;;
toml)
    config=(.tombi.toml tombi.toml .config/tombi.toml pyproject.toml)
    list=("$lib/tracked.sh" '*.toml')
    ;;
yaml)
    # prettier takes indentation from .editorconfig.
    config=(.yamllint .yamllint.yaml .yamllint.yml '.prettierrc*'
        'prettier.config.*' .prettierignore .editorconfig '*/.editorconfig'
        package.json bun.lock)
    list=("$lib/tracked.sh" '*.yaml' '*.yml')
    ;;
editorconfig)
    config=(.editorconfig '*/.editorconfig' .editorconfig-checker.json .ecrc)
    list=("$lib/tracked.sh")
    ;;
emdash)
    config=()
    list=("$lib/tracked.sh")
    ;;
*)
    echo "scope.sh: unknown kind: $kind" >&2
    exit 2
    ;;
esac

# Deletions count here: removing a configuration changes it too.
if ((${#config[@]})) && ! git diff --quiet "$LINT_BASE" HEAD -- "${config[@]}"; then
    echo all
    exit 0
fi

# Reads all of its input: grep -q would stop at the first match and fail the
# producer with SIGPIPE under pipefail.
changed=$("${list[@]}" | grep -cz . || true)
# A shuck configuration gives shuck the sh scripts too.
if [[ $kind == zsh ]] && shuck_configured; then
    changed=$((changed + $("$lib/filetype.sh" sh | grep -cz . || true)))
fi
((changed)) && echo changed || echo none
