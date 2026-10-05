#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/actionlint.sh
#
#

# Runs actionlint over the repository's workflows. A repository without a
# `.github/actionlint.yaml` of its own that declares
# `@chewygumxx/actionlint-config` is checked by that, as its own scripts pass
# it with `-config-file`.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=actions/lib/shared-config.sh
source "$lib/shared-config.sh"

args=()
if [[ ! -e .github/actionlint.yaml && ! -e .github/actionlint.yml ]] &&
    supply actionlint-config; then
    args=(-config-file node_modules/@chewygumxx/actionlint-config/config.yaml)
fi

actionlint -color "${args[@]}"
