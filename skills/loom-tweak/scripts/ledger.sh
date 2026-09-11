#!/usr/bin/env bash
# loom-tweak's ledger plumbing. Finds the branch's run ledger and splices a
# tweak entry into the right place, so the skill does not have to think about
# either.
#
# A tweak heads itself "## Tweak <n>", never "## Round <n>". A round heading
# with no "### Land - [x]" under it makes the branch look like it has a loom
# round that never finished.
#
# Usage:
#   ledger.sh find                 preconditions plus where to write, as key=value
#   ledger.sh add <block-file>     splice that block into the ledger (and report)
#
# find exits 0 with ledger=none when the branch has no ledger. That is normal:
# a tweak runs with or without one.
set -uo pipefail

say() { printf '%s\n' "$1"; }
die() { say "ok=no"; say "reason=$1"; exit 1; }

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git worktree"
cd "$root" || exit 2
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

# The contract's hard stops. Neither is a tweak's to work around.
[ "$(basename "$root")" = momentum ] && die "this is the read-only reference checkout, move to a feature worktree"
[ "$branch" = main ] && die "the branch is main, cut a branch first"

ledger="$(ls -t artifacts/loom/*-ledger.md 2>/dev/null | head -1)"

case "${1:-find}" in
find)
    say "worktree=$root"
    say "branch=$branch"
    if [ -z "$ledger" ]; then
        say "ledger=none"
        say "tweak=1"
    else
        say "ledger=$ledger"
        say "slug=$(basename "$ledger" -ledger.md)"
        last="$(grep -oE '^## Tweak [0-9]+' "$ledger" | grep -oE '[0-9]+' | sort -n | tail -1)"
        say "tweak=$(( ${last:-0} + 1 ))"
        report="artifacts/loom/$(basename "$ledger" -ledger.md)-report.md"
        [ -f "$report" ] && say "report=$report"
    fi
    say "ok=yes"
    ;;

add)
    block="${2:?usage: ledger.sh add <block-file>}"
    [ -f "$block" ] || die "no such block file: $block"
    [ -n "$ledger" ] || die "no ledger on this branch, nothing to update"

    # The spine ends with "## Needs human eyes" and "## Blockers", and the
    # contract keeps those last. Go in above them where they exist.
    anchor="$(grep -nE '^## (Needs human eyes|Blockers)' "$ledger" | head -1 | cut -d: -f1)"
    tmp="$(mktemp)"
    if [ -n "$anchor" ]; then
        head -n "$(( anchor - 1 ))" "$ledger" > "$tmp"
        cat "$block" >> "$tmp"
        printf '\n' >> "$tmp"
        tail -n "+$anchor" "$ledger" >> "$tmp"
    else
        cat "$ledger" > "$tmp"
        printf '\n' >> "$tmp"
        cat "$block" >> "$tmp"
    fi
    mv "$tmp" "$ledger"
    say "ledger=$ledger updated"

    # The report is what /paperwork reads, so a tweak that only touched the
    # ledger would be invisible to the PR description. One line, not a section.
    report="artifacts/loom/$(basename "$ledger" -ledger.md)-report.md"
    if [ -f "$report" ]; then
        n="$(grep -oE '^## Tweak [0-9]+' "$block" | grep -oE '[0-9]+' | head -1)"
        subject="$(grep -m1 -E '^- Green:' "$block" | sed -E 's/^- Green: *//')"
        grep -qE '^## Tweaks' "$report" || printf '\n## Tweaks\n' >> "$report"
        printf -- '- Tweak %s: %s\n' "${n:-?}" "${subject:-unrecorded}" >> "$report"
        say "report=$report updated"
    fi
    say "ok=yes"
    ;;

*)
    die "unknown command: $1"
    ;;
esac
