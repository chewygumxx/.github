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
#
# With LINT_BASE naming a commit, only those changed between it and HEAD are
# printed, deletions aside: the files a scoped lint checks (see scope.sh).

set -euo pipefail

if [[ -n ${LINT_BASE-} ]]; then
    git diff -z --name-only --no-renames --diff-filter=d "$LINT_BASE" HEAD -- "$@"
else
    git ls-files -z -- "$@"
fi | while IFS= read -r -d '' file; do
    [ -L "$file" ] || printf '%s\0' "$file"
done
