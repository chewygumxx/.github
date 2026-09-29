#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/setup-tools.sh
#
#

# Usage: setup-tools.sh TOOL...
#
# Installs the named tools at the versions pinned in `actions/mise.toml` and
# puts their bin directories on the job's PATH. Later steps then run them
# from the calling repository's checkout, where mise would otherwise resolve
# that repository's own configuration instead.

set -euo pipefail

cd "$(dirname "$0")/.."
export MISE_TRUSTED_CONFIG_PATHS=$PWD
mise install "$@"
mise bin-paths "$@" >>"$GITHUB_PATH"
