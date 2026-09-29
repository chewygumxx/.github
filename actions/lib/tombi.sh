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
# as chewygumxx/nvim-config does. tombi reads its configuration from the
# working directory, so a repository without one of its own is checked from
# `actions/lint-toml`, whose `.tombi.toml` is the house style.

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)

mapfile -d '' files < <("$lib/tracked.sh" '*.toml')
((${#files[@]})) || exit 0

if [ -z "$(git ls-files -- tombi.toml .tombi.toml)" ] &&
    ! grep -qs '^\[tool\.tombi' pyproject.toml; then
    echo "No tombi configuration in the repository; using the house style."
    files=("${files[@]/#/$PWD/}")
    cd "$lib/../lint-toml"
fi

status=0
tombi format --check --diff --offline -- "${files[@]}" || status=1
tombi lint --error-on-warnings --offline -- "${files[@]}" || status=1
exit "$status"
