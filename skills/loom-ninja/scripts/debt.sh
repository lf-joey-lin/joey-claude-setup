#!/usr/bin/env bash
# loom-ninja's preconditions and review-debt arithmetic. One block of
# key=value lines for the orchestrator to read, so no agent has to do this.
#
# Ninja's licence to skip the branch-scoped review stages (probe deep, shape,
# tidy) is that they already ran over this branch and cleared it. This script
# is what checks that licence is real, and how far past it the branch has
# drifted since.
#
# Usage: debt.sh
# Exit 0 with ok=yes when ninja may run, exit 1 with ok=no and a reason.
set -uo pipefail

say() { printf '%s\n' "$1"; }
die() { say "ok=no"; say "reason=$1"; say "next=$2"; exit 1; }

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git worktree" "cd into a momentum worktree"
cd "$root" || exit 2

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
say "worktree=$root"
say "branch=$branch"

# The three refusals, same as loom-adopt's.
[ "$(basename "$root")" = momentum ] && die "this is the read-only reference checkout" "move to a feature worktree"
[ "$branch" = main ] && die "the branch is main" "cut a branch first"

ledger="$(ls -t artifacts/loom/*-ledger.md 2>/dev/null | head -1)"
[ -n "$ledger" ] || die "no loom ledger on this branch" "/loom --in $root <request>, or /loom-finish"
say "ledger=$ledger"
say "slug=$(basename "$ledger" -ledger.md)"

# The last round, and whether it finished. A plain first /loom run has no
# "## Round" heading at all - its stages sit at the top level - so both shapes
# have to be read.
lastround="$(grep -nE '^## Round [0-9]+' "$ledger" | tail -1)"
if [ -n "$lastround" ]; then
  ln="${lastround%%:*}"
  head="${lastround#*:}"
  roundno="$(printf '%s' "$head" | grep -oE '[0-9]+' | head -1)"
  # Both heading forms: loom-finish writes "### Land", a round that numbers its
  # stages writes "### Land R<n>".
  landed="$(tail -n "+$ln" "$ledger" | grep -cE '^### Land( R[0-9]+)? - \[x\]' || true)"
  kind="$(printf '%s' "$head" | grep -oE '\((ninja|loom-finish)\)' || echo '(loom)')"
else
  roundno=1
  landed="$(grep -cE '^## Land( R[0-9]+)? - \[x\]' "$ledger" || true)"
  kind='(loom)'
fi
say "last_round=$roundno"
say "last_round_kind=$kind"
say "next_round=$((roundno + 1))"

# Land is only ever marked [x] after the gate was accepted, so it is the one
# line that proves the whole tail ran. An unfinished round is a resume, not a
# ninja round, and ninja is not the thing that resumes it.
[ "${landed:-0}" -ge 1 ] || die "round $roundno never landed (it is unfinished or blocked)" \
  "resume it: /loom --in $root, or /loom-finish"

# The reviewed base is the commit the branch-scoped review stages last
# covered. Ninja carries it forward untouched; only a settle-up moves it.
debtline="$(grep -m1 -E '^- Ninja debt:' "$ledger" || true)"
if [ -n "$debtline" ]; then
  rounds="$(printf '%s' "$debtline" | grep -oE '[0-9]+ rounds' | grep -oE '[0-9]+')"
  rbase="$(printf '%s' "$debtline" | grep -oE 'since [0-9a-f]{7,40}' | awk '{print $2}')"
else
  rounds=0
  rbase="$(git rev-parse HEAD)"
fi
git cat-file -e "${rbase}^{commit}" 2>/dev/null || rbase="$(git rev-parse HEAD)"
say "reviewed_base=$rbase"
say "ninja_rounds=$rounds"

# What is unreviewed: production lines and files only. Specs inflate the line
# count fast and are not what shape and tidy are being deferred over.
#
# --first-parent --no-merges, not a plain base..HEAD diff. A round ends by
# merging origin/main, so a two-dot diff counts everything main brought in as
# unreviewed work: measured 11953 lines against 0 real ones on the
# tableGrouping branch, which would put every branch over the cap the moment it
# merged and turn the warning into noise. The first-parent walk counts only
# commits authored on this branch. It double-counts a line two rounds both
# touched, which is churn and is the honest side to err on.
log_paths=(-- src ':(exclude)*.spec.ts')
read -r ins del <<<"$(git log --first-parent --no-merges --numstat --format= "$rbase"..HEAD "${log_paths[@]}" 2>/dev/null \
  | awk '{i+=$1; d+=$2} END {print (i+0), (d+0)}')"
files="$(git log --first-parent --no-merges --name-only --format= "$rbase"..HEAD \
  -- src ':(exclude)*.spec.ts' ':(exclude)*.stories.ts' 2>/dev/null | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"
say "unreviewed_lines=$((ins + del))"
say "unreviewed_files=$files"

# Warn, never block. The cap is a number to report loudly, not a gate: a round
# refused mid-queue is worse than a round that tells the truth about its debt.
over=""
[ "$rounds" -ge 3 ] && over="$over rounds>=3"
[ "$((ins + del))" -gt 150 ] && over="$over lines>150"
[ "$files" -gt 5 ] && over="$over files>5"
grep -qE '^- Tripwire: fired' "$ledger" && over="$over tripwire"
if [ -n "$over" ]; then
  say "debt_over_cap=yes"
  say "debt_triggers=${over# }"
else
  say "debt_over_cap=no"
fi

say "ok=yes"
