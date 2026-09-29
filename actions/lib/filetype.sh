#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/filetype.sh
#
#

# Usage: filetype.sh sh|zsh
#
# Prints the tracked shell scripts of one family, NUL-delimited.
#
#   sh   sh, bash, dash and ksh: shellcheck and shfmt parse these
#   zsh  zsh: only shuck parses it
#
# A file belongs to a family by, in order: its extension, its basename (zsh
# startup files), its shebang, then a vim modeline in its first or last five
# lines, as vim itself reads them. The modeline catches extensionless files
# such as autoloaded zsh functions, whose shebang is often absent or
# `#!/bin/false`.

set -euo pipefail

want=$1

family() {
    local file=$1 base=${1##*/} line

    case $base in
    *.zsh | *.zsh-theme) echo zsh && return ;;
    .zshrc | .zshenv | .zprofile | .zlogin | .zlogout) echo zsh && return ;;
    zshrc | zshenv | zprofile | zlogin | zlogout) echo zsh && return ;;
    *.sh | *.bash | *.ksh) echo sh && return ;;
    *.*) return ;;
    esac

    line=$(head -n 1 -- "$file")
    case $line in
    '#!'*zsh*) echo zsh && return ;;
    '#!'*/sh | '#!'*/sh' '* | '#!'*[/\ ]bash* | '#!'*[/\ ]dash* | '#!'*[/\ ]ksh*)
        echo sh && return
        ;;
    esac

    line=$(head -n 5 -- "$file" && tail -n 5 -- "$file")
    line=$(printf '%s\n' "$line" |
        grep -oE '(vim?|ex):.*(ft|filetype)=[a-z]+' | head -n 1 || true)
    case $line in
    *=zsh) echo zsh ;;
    *=sh | *=bash) echo sh ;;
    esac
}

"$(dirname "$0")/tracked.sh" | while IFS= read -r -d '' file; do
    if [ "$(family "$file" 2>/dev/null)" = "$want" ]; then
        printf '%s\0' "$file"
    fi
done
