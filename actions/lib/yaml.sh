#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/yaml.sh
#
#

# Checks formatting of every tracked YAML file with prettier and lints it with
# yamllint, as chewygumxx/nvim-config does. Neither needs a configuration in
# the repository: prettier's defaults take indentation from `.editorconfig`,
# and yamllint falls back to the house style in `actions/config`. A
# repository's own prettier or yamllint configuration takes precedence.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)

mapfile -d '' files < <("$lib/tracked.sh" '*.yaml' '*.yml')
((${#files[@]})) || exit 0

export YAMLLINT_CONFIG_FILE=$lib/../config/yamllint.yaml

# A repository's own `.yamllint` may extend `@chewygumxx/yamllint-config`
# from `node_modules`, which is not installed here. Put the identical copy at
# that path while yamllint runs, and remove only what was created, so a later
# step in the caller's job sees the checkout as it was.
shared=node_modules/@chewygumxx/yamllint-config
if [[ ! -e $shared ]]; then
    created=$shared
    while [[ ! -e $(dirname "$created") ]]; do
        created=$(dirname "$created")
    done
    trap 'rm -rf -- "$created"' EXIT
    mkdir -p -- "$shared"
    cp -- "$YAMLLINT_CONFIG_FILE" "$shared/config.yaml"
fi

status=0
prettier --check -- "${files[@]}" || status=1
yamllint --strict --format github -- "${files[@]}" || status=1
exit "$status"
