#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/emdash.sh
#
#

# Fails on any em dash (U+2014) in a tracked text file, annotating each one.
# The house style prohibits them; the pre-commit hooks reject one in staged
# lines, and this holds the whole tree to the same rule. With LINT_BASE, only
# the files changed since it are searched (see tracked.sh).

set -euo pipefail

lib=$(cd "$(dirname "$0")" && pwd)

# git grep given no path searches everything, so an empty change set is done.
paths=()
if [[ -n ${LINT_BASE-} ]]; then
    mapfile -d '' paths < <("$lib/tracked.sh")
    ((${#paths[@]})) || exit 0
fi

# Escapes a value for a workflow command property.
escape() {
    local value=${1//%/%25}
    value=${value//$'\r'/%0D}
    value=${value//$'\n'/%0A}
    value=${value//:/%3A}
    printf '%s' "${value//,/%2C}"
}

matches=$(mktemp)
trap 'rm -f -- "$matches"' EXIT

# Exit 1 is no match; anything above it is git failing.
status=0
git --literal-pathspecs grep -z -nIP --column '\x{2014}' -- "${paths[@]}" \
    >"$matches" || status=$?
((status <= 1)) || exit "$status"

found=0
while IFS= read -r -d '' file && IFS= read -r -d '' line &&
    IFS= read -r -d '' column && IFS= read -r text; do
    printf '%s:%s:%s: %s\n' "$file" "$line" "$column" "$text"
    printf '::error file=%s,line=%s,col=%s,title=Em dash::%s\n' \
        "$(escape "$file")" "$line" "$column" "Em dash (U+2014) is prohibited"
    found=1
done <"$matches"
exit "$found"
