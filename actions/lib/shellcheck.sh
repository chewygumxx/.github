#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/shellcheck.sh
#
#

# Runs shellcheck over the tracked sh, bash, dash and ksh scripts. A
# repository without a `.shellcheckrc` of its own that declares
# `@chewygumxx/shellcheck-config` is checked by that, as its own scripts pass
# it with `--rcfile`.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=actions/lib/shared-config.sh
source "$lib/shared-config.sh"

args=()
if [[ ! -e .shellcheckrc && ! -e shellcheckrc ]] && supply shellcheck-config; then
    args=(--rcfile node_modules/@chewygumxx/shellcheck-config/config.shellcheckrc)
fi

"$lib/filetype.sh" sh | xargs -0 -r shellcheck "${args[@]}" --
