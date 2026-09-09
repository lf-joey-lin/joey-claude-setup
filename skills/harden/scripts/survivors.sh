#!/usr/bin/env bash
# Print the actionable mutants from a Stryker mutation-report.json.
#
# Prints only the statuses worth acting on. Ignored and CompileError are dropped: a
# mutant that could not compile was never a possible bug, and an ignored one was
# never tested. (Stryker.NET's per-file summary table counts Ignored in its
# "# survived" column and so overstates badly on a scoped run; reading the report
# avoids that.)
#
# Written for StrykerJS in src/ui-app: run with `--reporters clear-text,progress,json`
# and the report lands at reports/mutation/mutation.json. Stryker.NET's Json reporter
# writes the same schema to <output>/reports/mutation-report.json, so this reads that
# too when the .NET side arrives.
#
# Usage: survivors.sh <path-to-mutation-report.json> [status ...]
#        default statuses: Survived NoCoverage Timeout
set -euo pipefail

report=${1:-}
if [ -z "$report" ] || [ ! -f "$report" ]; then
    echo "usage: $(basename "$0") <mutation-report.json> [status ...]" >&2
    exit 2
fi
shift || true
statuses=("$@")
[ ${#statuses[@]} -eq 0 ] && statuses=(Survived NoCoverage Timeout)

filter=$(printf '%s\n' "${statuses[@]}" | jq -R . | jq -sc .)

jq -r --argjson want "$filter" '
  .files | to_entries[] | .key as $file | .value.mutants[]
  | select(.status as $s | $want | index($s))
  | [ .status,
      "\($file):\(.location.start.line)",
      .mutatorName,
      ((.replacement // "") | gsub("\\s+"; " ") | .[0:70])
    ] | @tsv
' "$report" | sort

echo "---" >&2
jq -r '[.files[].mutants[].status] | group_by(.) | map("\(.[0])=\(length)") | join("  ")' "$report" >&2
