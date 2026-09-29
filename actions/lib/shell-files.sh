#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/shell-files.sh
#
#

# Prints the tracked POSIX-family shell scripts, NUL-delimited: files named
# `*.sh` or `*.bash`, and extensionless files with an sh, bash, dash or ksh
# shebang (e.g. husky hooks). zsh is excluded; neither shellcheck nor shfmt
# parses it.

set -euo pipefail

git ls-files -z | while IFS= read -r -d '' file; do
    base=${file##*/}
    case $base in
    *.sh | *.bash) ;;
    *.*) continue ;;
    *)
        [ -f "$file" ] || continue
        head -n 1 -- "$file" | grep -qE '^#!.*[/ ](ba|da|k)?sh([[:space:]]|$)' ||
            continue
        ;;
    esac
    printf '%s\0' "$file"
done
