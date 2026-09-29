#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/tracked.sh
#
#

# Usage: tracked.sh [PATHSPEC...]
#
# Prints the tracked files matching PATHSPEC, NUL-delimited, leaving out
# symlinks: a linter following one would check the target twice, or fail on
# a target outside the repository.

set -euo pipefail

git ls-files -z -- "$@" | while IFS= read -r -d '' file; do
    [ -L "$file" ] || printf '%s\0' "$file"
done
