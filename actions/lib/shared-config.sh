#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/shared-config.sh
#
#

# Sourced, from the root of the calling repository's checkout:
#
#   source "$lib/shared-config.sh"
#   if supply shellcheck-config; then ...
#
# A repository's configuration may extend, or its scripts name, a shared one
# in `node_modules/@chewygumxx`, which these jobs do not install. `supply NAME`
# puts `@chewygumxx/NAME` there when the repository declares it in
# `package.json` and has not installed it: the version its `bun.lock`
# resolves (the latest without one), fetched from the npm registry and
# checked against the lock's integrity hash. It returns 0 when the package is
# then in place, and 1 when the repository does not declare it; any other
# failure exits. What was created is removed on exit, so a later step in the
# caller's job sees the checkout as it was; this file owns the EXIT trap.

shared_registry=https://registry.npmjs.org

shared_created=()
# shellcheck disable=SC2329 # Invoked by the trap.
shared_cleanup() {
    if ((${#shared_created[@]})); then
        rm -rf -- "${shared_created[@]}"
    fi
}
trap shared_cleanup EXIT

supply() {
    local name=@chewygumxx/$1
    local dir=node_modules/$name
    local entry version integrity metadata tarball created tgz
    [[ -e $dir ]] && return 0
    [[ -f package.json ]] || return 1
    jq -e --arg name "$name" \
        '(.dependencies // {}) + (.devDependencies // {}) | has($name)' \
        package.json >/dev/null || return 1

    # One line per package: "name": ["name@version", "", {...}, "sha512-..."]
    entry=$(grep -m 1 -F "    \"$name\": [\"$name@" bun.lock 2>/dev/null || true)
    if [[ -n $entry ]]; then
        version=$(sed -E 's/^[^[]*\["[^"]*@([^"@]+)".*/\1/' <<<"$entry")
        integrity=$(grep -oE '"sha512-[A-Za-z0-9+/=]+"' <<<"$entry" | tr -d '"')
    else
        version=latest
    fi

    metadata=$(curl -fsSL --retry 3 "$shared_registry/$name/$version")
    tarball=$(jq -r .dist.tarball <<<"$metadata")
    integrity=${integrity:-$(jq -r .dist.integrity <<<"$metadata")}

    created=$dir
    while [[ ! -e $(dirname "$created") ]]; do
        created=$(dirname "$created")
    done
    tgz=$(mktemp)
    shared_created+=("$created" "$tgz")
    curl -fsSL --retry 3 -o "$tgz" "$tarball"
    if [[ sha512-$(openssl dgst -sha512 -binary "$tgz" | base64 -w 0) != "$integrity" ]]; then
        echo "::error::$name@$version does not match its integrity $integrity" >&2
        exit 1
    fi
    mkdir -p -- "$dir"
    tar -xzf "$tgz" -C "$dir" --strip-components 1
    echo "Supplied $name@$(jq -r .version "$dir/package.json") from the npm registry"
}
