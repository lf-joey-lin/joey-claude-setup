#!/usr/bin/env bash
# The ui-app CI mirror. Runs every check loom-gate runs, in three lanes instead of
# one queue, and prints a scorecard of real exit codes.
#
# Measured on momentum main, 2026-09-08, warm worktree, 20 cores:
#   lint 10s, typecheck 17s, test:ci 122s, build 46s, build-storybook 17s,
#   test:a11y 75s. Sequential 4:47. These three lanes: 3:24, all exit 0.
#
# Lane B is serial inside itself because typecheck, build and the storybook
# build all write .nuxt. Lane C is test:ci alone. Storybook and a11y are
# always run: lane C is 122s and lane B is 155s, so they cost about 33s of
# total wall time, which is not worth the risk of guessing that a .ts change
# cannot alter rendered markup.
#
# Usage: gate.sh <slug> [base-ref] [story-base]
#   <slug>        names the log directory, artifacts/loom/<slug>/gate/
#   [base-ref]    what to diff for the scope check (default origin/main)
#   [story-base]  what to diff for the story check (default base-ref). Pass this
#                 round's base commit: components an earlier round added were
#                 already certified by that round's gate, and re-flagging them
#                 every round is noise.
#
# Exit 0 only when every check that ran was green. Read the VERDICT line, not
# just the exit code - piping this script's output replaces $? with the pipe's.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gate: not a git worktree"; exit 2; }
slug="${1:?usage: gate.sh <slug> [base-ref]}"
base="${2:-origin/main}"
storybase="${3:-$base}"
ui="$root/src/ui-app"
out="$root/artifacts/loom/$slug/gate"
mkdir -p "$out"

cd "$root" || exit 2
changed="$(git diff --name-only "$base"...HEAD; git status --porcelain | awk '{print $2}')"
changed="$(printf '%s\n' "$changed" | sort -u | sed '/^$/d')"

# Scope. Anything outside ui-app and the two realm BFFs is not this gate's to
# certify, and saying so is not optional - a half-covered branch reported as
# whole is the one failure this script must not produce.
outside="$(printf '%s\n' "$changed" | grep -vE '^src/(ui-app|acs-bff|app-bff)/' | grep -v '^artifacts/' || true)"
bff="$(printf '%s\n' "$changed" | grep -oE '^src/(acs-bff|app-bff)' | sort -u || true)"

# Story check. The a11y suite mounts stories and nothing else, so a new
# component with no story is never scanned and a green a11y pass does not
# cover it.
# It REPORTS and never fails the run. A literal grep for the component's own
# name cannot see indirect rendering - a parent's story mounting the child is
# real coverage, and this check called three such components missing on the
# groupedSortToggle branch whose own gate had traced them to Grouped* stories.
# So the orchestrator has to get a REVIEW line answered before land; a script
# guessing wrong in the failing direction would block every round that adds a
# component.
storyreview=""
for f in $(printf '%s\n' "$changed" | grep -E '^src/ui-app/app/(components|layouts|pages)/.*\.vue$' || true); do
  [ -f "$f" ] || continue
  git ls-tree -r --name-only "$storybase" -- "$f" 2>/dev/null | grep -q . && continue   # not new this round
  name="$(basename "$f" .vue)"
  grep -rqlF "$name" "$ui"/app --include='*.stories.ts' 2>/dev/null || storyreview="$storyreview $f"
done

run() { # run <label> <logfile> <command...>
  local label="$1" log="$2"; shift 2
  local s e rc
  s=$(date +%s); "$@" >"$log" 2>&1; rc=$?; e=$(date +%s)
  printf '%s|%s|%s|%s\n' "$label" "$rc" "$((e-s))s" "$log" >>"$out/.rows"
  return $rc
}

: >"$out/.rows"
cd "$ui" || { echo "gate: no src/ui-app at $ui"; exit 2; }

(
  run lint "$out/lint.log" npm run lint
) &
laneA=$!

(
  run typecheck "$out/typecheck.log" npx nuxt typecheck \
    && run build "$out/build.log" npm run build \
    && run storybook "$out/storybook.log" npm run build-storybook \
    && run a11y "$out/a11y.log" npm run test:a11y
) &
laneB=$!

(
  run test:ci "$out/testci.log" npm run test:ci
) &
laneC=$!

laneD=""
if [ -n "$bff" ]; then
  (
    cd "$root" || exit 1
    for b in $bff; do
      n="$(basename "$b")"
      run "dotnet-build:$n" "$out/dotnet-build-$n.log" dotnet build "$b/$n.slnx" -c Release || break
    done
    # The .NET gate is the coverage-threshold target; `test` alone enforces
    # nothing. Two traps in resolving the project names, and getting it wrong
    # HANGS this lane rather than failing it: `nx show projects` prints the whole
    # list as one line of JSON, and .NET project names are PascalCase
    # (Laserfiche.AppBff.Tests) and never contain the kebab-case folder name. So a
    # line-wise grep for "app-bff" matches the entire JSON line and hands
    # run-many almost every project in the monorepo, which takes about 20 minutes,
    # fails on unrelated projects, and wedges the shared NuGet cache for every
    # other worktree on the box. The timeout is the backstop: a future mis-scope
    # fails this lane instead of blocking `wait` forever and eating the scorecard.
    pat=""
    for b in $bff; do
      p="$(basename "$b" | sed -E 's/(^|-)([a-z])/\U\2/g')"   # app-bff -> AppBff
      pat="${pat:+$pat|}Laserfiche\.$p(\..*)?\.Tests"
    done
    projects="$(npx nx show projects 2>/dev/null | tr ',' '\n' | tr -d '[]"' \
      | grep -E "^($pat)$" | paste -sd, - || true)"
    if [ -n "$projects" ]; then
      run "dotnet-coverage" "$out/dotnet-coverage.log" \
        timeout 1200 npx nx run-many -t test,coverage-threshold --projects="$projects"
    else
      printf 'dotnet-coverage|2|0s|%s\n' "nx resolved no test project for [$bff], run it by hand" >>"$out/.rows"
    fi
  ) &
  laneD=$!
fi

wait $laneA; wait $laneB; wait $laneC
[ -n "$laneD" ] && wait $laneD

# Scorecard. Exit codes are authoritative; log text is not.
echo
echo "gate scorecard ($slug, scope base $base, story base $storybase)"
fail=0
while IFS='|' read -r label rc took log; do
  if [ "$rc" = 0 ]; then
    printf '  %-18s exit 0   %-6s %s\n' "$label" "$took" "$log"
  else
    printf '  %-18s exit %-3s %-6s %s   FAILED\n' "$label" "$rc" "$took" "$log"
    fail=1
  fi
done <"$out/.rows"

# A lane that broke early never wrote its later rows, so name what never ran.
for expect in lint typecheck build storybook a11y test:ci; do
  grep -q "^$expect|" "$out/.rows" || { printf '  %-18s DID NOT RUN (an earlier check in its lane failed)\n' "$expect"; fail=1; }
done

if [ -n "$storyreview" ]; then
  echo "  story check       REVIEW - no story file names these, confirm what mounts them:"
  printf '%s\n' $storyreview | sed 's/^/                      /'
  echo "                    (indirect mounting counts; a component nothing mounts is NOT READY)"
else
  echo "  story check       ok"
fi
[ -n "$outside" ] && printf '  scope             PARTIAL - this gate does not cover:\n%s\n' "$(printf '%s\n' "$outside" | sed 's/^/                      /')"
[ -z "$bff" ] && echo "  dotnet            SKIPPED (no BFF file changed)"
echo "  ci still owns     container builds, pr-metadata, translation parity"
echo
[ "$fail" = 0 ] && echo "VERDICT READY" || echo "VERDICT NOT READY"
exit $fail
