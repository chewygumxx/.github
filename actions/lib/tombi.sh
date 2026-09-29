#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/tombi.sh
#
#

# Checks formatting and lints every tracked TOML file with tombi, offline,
# as chewygumxx/nvim-config does. tombi has no option naming a configuration
# file, but it falls back to a user-level one under `XDG_CONFIG_HOME`: that is
# pointed at `actions/config`, whose `tombi/config.toml` is the house style,
# and a configuration in the repository still takes precedence.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)

mapfile -d '' files < <("$lib/tracked.sh" '*.toml')
((${#files[@]})) || exit 0

export XDG_CONFIG_HOME=$lib/../config

status=0
tombi format --check --diff --offline -- "${files[@]}" || status=1
tombi lint --error-on-warnings --offline -- "${files[@]}" || status=1
exit "$status"
