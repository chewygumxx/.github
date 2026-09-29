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

status=0
prettier --check -- "${files[@]}" || status=1
yamllint --strict --format github -- "${files[@]}" || status=1
exit "$status"
