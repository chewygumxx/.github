#!/usr/bin/env bash
# vim:set expandtab shiftwidth=4 filetype=bash:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/.github.git
# ::: :/actions/lib/base.sh
#
#

# Usage: base.sh
#
# Prints the commit the lints can take as passing, for scope.sh to diff HEAD
# against, or nothing, with a notice, when every file must be checked.
#
#   pull_request  the fork point from the base branch: the pull request is
#                 answerable for its own changes
#   push          the commit of the caller workflow's last successful push
#                 run on this branch, so a failure keeps its files in scope
#                 until a run passes, however many pushes leave them alone
#   otherwise     nothing: workflow_dispatch and the rest check everything
#
# Reads the event from the environment, as the detect action passes it:
# EVENT, PR_BASE, REF_TYPE, REF_NAME, WORKFLOW_REF, REPOSITORY, API and
# TOKEN. Under act (ACT set) it prints nothing: act lints the working tree,
# whose uncommitted changes no diff of HEAD sees.

set -euo pipefail

full() {
    echo "::notice title=Full lint::Checking every file: $*" >&2
    exit 0
}

[[ -z ${ACT-} ]] || full "running under act"

case $EVENT in
pull_request | pull_request_target)
    base=$(git merge-base "$PR_BASE" HEAD 2>/dev/null) ||
        full "$PR_BASE is not in the checkout"
    ;;
push)
    [[ $REF_TYPE == branch ]] || full "a push of a $REF_TYPE"
    # WORKFLOW_REF is owner/repo/.github/workflows/FILE@ref, naming the
    # caller even from within a reusable workflow.
    workflow=${WORKFLOW_REF%%@*}
    workflow=${workflow##*/}
    runs=$(curl -fsSL --retry 3 -G \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Accept: application/vnd.github+json' \
        --data-urlencode "branch=$REF_NAME" \
        -d event=push -d status=success -d per_page=1 \
        "$API/repos/$REPOSITORY/actions/workflows/$workflow/runs") ||
        full "the runs of $workflow could not be listed; grant the caller actions: read"
    base=$(jq -r '.workflow_runs[0].head_sha // empty' <<<"$runs")
    [[ -n $base ]] || full "$workflow has no successful push run on $REF_NAME"
    git cat-file -e "$base^{commit}" 2>/dev/null ||
        full "$base, the last successful run, is not in the checkout"
    ;;
*)
    full "a $EVENT event"
    ;;
esac

echo "$base"
