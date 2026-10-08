#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/shuck.sh
#
#

# Lints and checks the formatting of shell scripts with shuck.
#
# A repository with a shuck configuration has chosen shuck for every shell
# script, so shuck runs over the whole tree and its `[per-file-shell]` map
# decides each file's dialect, as chewygumxx/zsh-config does. Its walk skips a
# file with no extension and no shebang, such as an autoloaded function, even
# when the map names it, so the detected zsh scripts are passed as well: shuck
# reads a file it is named, and lints each file once. Otherwise only the
# detected zsh scripts are passed, forced to the zsh dialect: shuck's own
# detection can misread a `.plugin.zsh` file as sh.
#
# With LINT_BASE, only the scripts changed since it are passed (see
# tracked.sh), with a configuration the sh scripts among them too, and the
# tree is not walked.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)

mapfile -d '' files < <("$lib/filetype.sh" zsh)

status=0
if [ -n "$(git ls-files -- .shuck.toml shuck.toml)" ] && [ -n "${LINT_BASE-}" ]; then
    mapfile -d '' -O "${#files[@]}" files < <("$lib/filetype.sh" sh)
    ((${#files[@]})) || exit 0
    shuck check --output-format github -- "${files[@]}" || status=1
    shuck format --diff -- "${files[@]}" || status=1
elif [ -n "$(git ls-files -- .shuck.toml shuck.toml)" ]; then
    shuck check --output-format github -- . "${files[@]}" || status=1
    shuck format --diff -- . "${files[@]}" || status=1
else
    ((${#files[@]})) || exit 0
    zsh=(--config 'per-file-shell = { "**" = "zsh" }')
    shuck "${zsh[@]}" check --output-format github -- "${files[@]}" || status=1
    shuck "${zsh[@]}" format --diff -- "${files[@]}" || status=1
fi
exit "$status"
