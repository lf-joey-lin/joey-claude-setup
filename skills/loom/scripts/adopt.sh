#!/usr/bin/env bash
# The adopt lane's revert. loom-spec has already written the patch and recorded
# the base SHA; this takes the prototype out of the tree so the specs that lock
# it in can be born red.
#
# The orchestrator runs this AFTER the human approves loom-spec's bullets. That
# ordering is the whole point: this is the destructive step, and it must not
# happen before somebody said yes to what was read out of the diff.
#
# It is a fixed list of git commands checked on real exit codes, which is why
# the conductor may run it without breaching the no-source-reading rule.
#
# Usage:
#   adopt.sh <patch-path> <slug> <round>            revert uncommitted work
#   adopt.sh <patch-path> <slug> <round> <base-sha> revert to a --from base
#
# Exits non-zero, with the tree untouched, on anything unexpected.
set -uo pipefail

say() { printf '%s\n' "$1"; }
die() { say "ok=no"; say "reason=$1"; exit 1; }

patch="${1:?usage: adopt.sh <patch-path> <slug> <round> [base-sha]}"
slug="${2:?missing slug}"
round="${3:?missing round}"
base="${4:-}"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git worktree"
cd "$root" || exit 2
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

# The contract's hard stops. Neither is this script's to work around.
[ "$(basename "$root")" = momentum ] && die "this is the read-only reference checkout"
[ "$branch" = main ] && die "the branch is main"

# Refuse to revert without a capture that actually replays. loom-spec checked
# this too; checking again here is cheap and this is the irreversible step.
[ -f "$patch" ] || die "no patch at $patch - nothing proves the work is recoverable"
[ -s "$patch" ] || die "patch at $patch is empty"
git apply --check --reverse "$patch" 2>/dev/null || die "patch does not replay against this tree, refusing to revert"

say "patch=$patch"
say "pre_revert_sha=$(git rev-parse HEAD)"

if [ -n "$base" ]; then
    # A --from source: the prototype is committed, so rewind to its base. The
    # unpushed check happened in loom-spec; re-assert it rather than trust it.
    git branch -r --contains "$base" 2>/dev/null | grep -q . && \
        die "commits at or after $base are pushed, not ours to rewind"
    git reset --hard "$base" || die "reset to $base failed"
    say "mode=reset"
    say "base=$base"
else
    # -u and never -a: untracked files go, gitignored files stay, which keeps
    # the ledger and the patch just written out of the stash.
    git stash push -u -m "loom-spec round $round: $slug" || die "stash failed"
    ref="$(git stash list --format='%H %gs' | grep -m1 "loom-spec round $round: $slug" | awk '{print $1}')"
    [ -n "$ref" ] || die "stashed, but could not find the ref back - do not continue"
    say "mode=stash"
    say "stash_ref=$ref"
fi

# The tree must actually be clean now, or the revert half-happened and every
# spec after this would be born red for the wrong reason.
[ -z "$(git status --porcelain -- . ':(exclude)artifacts/loom')" ] || \
    die "tree still dirty after revert - stop and look before building"

say "ok=yes"
