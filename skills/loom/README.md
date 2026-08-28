# loom: a slice-based dev pipeline for momentum ui-app

loom builds a ui-app feature the way a careful engineer works when nobody is
making them do paperwork: in small vertical slices, each proven before the
next starts, with a skeptic trying to break each one while the context is
still hot. When a slice needs a data path that does not exist yet, the slice
reaches through the realm BFF too - the browser route is built via the
`api-integrator` skill inside the same run, so a vertical slice is actually
vertical. It was built from scratch as an alternative to the
spec/design/implement/test/review pipeline, after a critical review of that
pipeline; it deliberately fixes the problems that review found.

## The idea in five rules

1. **Ceremony scales with the change.** Every run starts with `loom-scout`,
   which sizes the work into a lane. A patch (one component, existing
   pattern) skips planning entirely and runs brief, build, probe, gate,
   land. A feature gets a slice plan. Anything bigger gets split into two
   runs. There is no maximal path that every two-file story has to pay.

2. **Vertical slices, born red.** A feature is built as 2 to 6 slices, each
   the smallest increment a user could notice, starting with a walking
   skeleton (route, shell, real data path, empty state). Each slice's
   acceptance checks are written as specs first and must be seen failing
   before the code exists. A test observed red-then-green has already proven
   it can fail, so loom needs no separate test-writing phase and no
   after-the-fact mutation sweep over slice work - the proof happened at
   birth, and the ledger records it. (Mutation checks still exist, but only
   for the exceptions: gate-written coverage tests and suspicious specs the
   probe flags.)

3. **A skeptic, not a review committee.** After every slice, `loom-probe`
   attacks it: awkward data (zero, one, hundreds, the 400-character label,
   the missing field), hostile states (error, double-submit, Esc), and
   static sweeps (hardcoded strings, hex, leftover console.logs). Findings
   are reproductions - an input and what it did - never style opinions, and
   the probe spec that caught a real bug gets promoted into the suite as a
   regression test. Finder and fixer are never the same agent. The single
   maintainability read (`loom-tidy`) runs once at the end, when the shape
   has settled.

4. **Claims carry evidence.** Every stage appends to one flight ledger
   (`src/ui-app/logs/loom/<slug>.md`): what it claims, the command that
   proved it, and what would disprove it. The orchestrator gates on those
   evidence lines, not on a subagent saying "done", and the final report is
   generated from the ledger so it cannot drift from what actually happened.
   The ledger is also the resume point - kill a run anywhere, invoke loom
   with the same request, it continues.

5. **One bar, two modes.** Attended and solo runs do exactly the same
   checking, probing, and gating. Attendance changes two things only: whether
   the run pauses at its two ask moments (after the brief, after the plan),
   and whether land may push. A solo run never pushes and never asks; it
   takes documented defaults and logs every one so the report shows what was
   assumed.

## Quickstart

```
/loom add a status filter to the submissions table
```

Attended run. Scout sets up the branch (worktree if the default checkout is
busy), recons the app, and comes back with a brief - you approve or adjust
it. Patch lane goes straight to building; feature lane shows you the slice
plan first. Then it runs to the end on its own: slices commit one by one,
probe attacks each, the gate mirrors CI, land merges main and asks before
pushing. You get a report whose every claim traces to a ledger entry.

```
/loom build the new usage dashboard page --solo
```

Same pipeline, zero questions, branch left local. Read the report, push, run
`/paperwork`.

Parallel: ask for several solo runs at once ("loom these three, solo") - each
gets its own worktree and ledger, so they cannot collide. Review each report
in the main session.

Flags: `--solo` (unattended, no push), `--no-push` (attended, land stops
before pushing).

## What runs when

| Stage | Skill | Patch lane | Feature lane |
| --- | --- | --- | --- |
| brief + workspace | loom-scout | yes | yes |
| ask moment 1 | (attended) | yes | yes |
| slice plan | loom-plan | skipped | yes |
| ask moment 2 | (attended) | skipped | yes |
| build + quick probe, per slice | loom-slice, loom-probe | one slice | 2 to 6 slices |
| deep probe | loom-probe | yes | yes |
| maintainability pass | loom-tidy | yes | yes |
| CI mirror | loom-gate | yes | yes |
| merge main, push, report | loom-land | yes | yes |

Fix turns happen inside the loop: a must-fix probe finding goes back to
loom-slice in fix mode (the reproduction becomes a failing spec, then a fix),
capped at two turns per probe. A must-fix that survives the cap stops the run
rather than accumulating - loom never carries a known-broken slice forward.

## Full-stack slices (the BFF half)

When scout finds the feature needs data no BFF route serves yet, the plan
gets a **bff slice**, and the run takes the feature lane even if the UI half
is trivial - the browser contract is a real design decision. The knowledge
stays in `api-integrator` (loom carries no copy); loom just schedules its
parts:

- **Plan time** runs api-integrator's Steps 0 to 4: read the upstream
  contract from the ACS or BPM source, pick the BFF, design the narrowed
  browser contract (verb normalized, fields cut, statuses mapped onto the
  reused outcome type).
- **Ask moment 2 is its approval gate**: the plan shows the route, verb, DTO
  cuts, and status map next to the slice list, so you approve the contract
  and the slices in one question. Solo runs log the full contract design in
  the ledger instead.
- **Slice time** runs its Steps 6 to 8 under loom's born-red rule: the
  harness tests (happy projection plus every promised failure mapping) are
  written and seen red before the wire/mapper/bridge/endpoint files exist.
  The thin ui-app service composable ships in the same slice, so the next
  slice (the walking skeleton) consumes a real endpoint.
- **Probe attacks the seam**: scripted upstream failures (`IsError` in a
  200, missing `Value`, wire drift), the cross-tenant id attempt, log-leak
  sweeps, and api-integrator's invariant checklist as a static sweep.
- **Gate adds the .NET rows**: the BFF build and the `coverage-threshold`
  nx target (the enforced 100% line + branch gate).

The bff slice always comes first, the skeleton second. An upstream that
belongs to neither realm is a blocker (api-integrator's "no new realm"
boundary) - that is a spec-driven feature, not a loom run.

## Context economics (why a long run does not drown)

Every stage runs in a fresh subagent, so the expensive noise - file reads,
test output, diffs, upstream source reading - dies with the stage that made
it. What survives is the flight ledger, and the ledger is state, not a log:
evidence lines are one line each, and anything longer (a failing suite, a
conflict listing) goes to a sidecar file under `logs/loom/<slug>/` with the
path in the ledger. The orchestrator itself holds almost nothing: stage
returns are capped at about fifteen lines, and mid-run it verifies a stage by
reading only that stage's ledger section, never the whole file - so its
context grows linearly with the stage count, not with the size of the work.
Only land reads the full ledger, once, in its own fresh context, to write the
report. If a very long run gets its orchestrator context summarized anyway,
nothing is lost: the ledger on disk is the authoritative state and the run
re-grounds from it, which is the same mechanism that makes a killed run
resumable.

## Using the stages standalone

Each stage is a normal skill and useful alone:

- `/loom-probe` - "try to break this branch". The adversarial pass on
  anything, loom-built or not.
- `/loom-gate` - "will CI pass" for ui-app and the BFFs. The local mirror in
  one shot.
- `/loom-tidy` - the maintainability pass with the over-engineering veto.
- `/loom-slice` - hand it one small verifiable change and it will build it
  checks-first.
- `/loom-land` - merge main, push, and write the report for a finished
  branch.

Standalone runs still read `skills/shared/loom-contract.md`, which is the
single place the repo facts (commands, coverage gate, translation rules, git
rules, hard stops) live. Change a fact there and every loom skill follows.

## Where loom ends

loom stops at a pushed (or deliberately local) branch plus its report. It
never creates a work item, never opens a PR, never deletes a worktree:

- `/paperwork` reads the loom report the way it reads a wrap-it-up report and
  files the TFS item and the PR.
- `/teardown` sweeps the worktree after the merge.
- `/pr-review-fixer` still owns working reviewer comments on the PR.

It coexists with the existing pipeline rather than replacing it: spec-ui and
design-ui remain the right tools when the open question is what to build
(product shape, UX research); loom assumes the request is roughly right and
optimizes how it gets built. For a genuinely open design question, run
ux-review or spec-ui first and loom the approved spec.

## How this differs from the joey-bot pipeline, deliberately

- **Lanes instead of one path.** The old pipeline's smallest honest route was
  still five stages; loom's patch lane is brief, build, probe, gate, land.
- **Tests are born, not backfilled.** update-tests wrote the suite after the
  fact and then had to mutation-check every test to prove it could fail.
  loom's checks are written first and observed red, which is the same proof
  for free, at the moment it is cheapest.
- **Probe replaces the review fan-out.** Four concurrent read-only reviews
  plus triage becomes one executing skeptic per slice plus one deep pass -
  fewer agents, findings that are reproductions instead of opinions, and the
  fixes happen while the slice is still in context.
- **Symmetric rigor.** The old autonomous path applied review fixes more
  aggressively than the attended path and skipped security-style scrutiny
  entirely; loom's bar is identical in both modes by construction.
- **Main is merged inside the run**, so paperwork's "main is merged"
  precondition is always satisfied and the run never dead-ends at the
  handoff.
- **One facts file.** The label rules, catalog rules, commands, and git rules
  live once in the shared contract instead of being copied into every skill.

## Limitations, stated plainly

- ui-app plus the realm BFFs, nothing further. A branch touching sso-auth,
  bff-platform, another C# service, or infra gets loom for the parts it owns
  and `prepare-to-ship` for the rest; the gate says so explicitly.
- Probe attacks through the unit-test harness, not a live browser. Live
  verification is deliberately out: chrome-devtools MCP cannot launch Chrome
  on this WSL box (see memory note; the Playwright-over-CDP workaround
  exists but is not wired into loom). The report's "needs human eyes"
  section carries what a browser would have checked.
- Slice checks lock in behavior early. That is the point, but it means a
  mid-run change of mind about the behavior is a plan edit plus deliberate
  spec changes, not a silent drift. The ledger records every such change.
- loom trusts the request's intent. It will flag a contradiction, but it
  does not run UX research; that is ux-review's job, before loom.
