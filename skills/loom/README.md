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
   regression test. Finder and fixer are never the same agent. The two
   reading passes run once each at the end, when the shape has settled:
   `loom-shape` for the concepts and `loom-tidy` for the files.

4. **Claims carry evidence.** Every stage appends to one flight ledger
   (`artifacts/loom/<slug>-ledger.md`): what it claims, the command that
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
before pushing), `--in <dir>` (run in a worktree that already exists instead
of cutting one).

`--in` is what lets a second and third request land on one branch: scout adopts
the worktree, the slug comes from the branch rather than the request, and each
later request is a new `## Round <n>` in the ledger the branch already has, the
way `loom-finish` rounds already work. It is how `m-board`'s per-worktree
queues run (`shell/README.md`), and it works typed by hand too.

## What runs when

| Stage | Skill | Patch lane | Feature lane |
| --- | --- | --- | --- |
| brief + workspace | loom-scout | yes | yes |
| ask moment 1 | (attended) | yes | yes |
| slice plan | loom-plan | skipped | yes |
| ask moment 2 | (attended) | skipped | yes |
| build + quick probe, per slice | loom-crew, driving loom-slice and loom-probe | one slice | 2 to 6 slices |
| deep probe | loom-probe | yes | yes |
| structural pass | loom-shape | yes | yes |
| reshape turn, if one is priced | loom-slice | at most one | at most one |
| maintainability pass | loom-tidy | yes | yes |
| CI mirror | loom-gate | yes | yes |
| merge main, push, report | loom-land | yes | yes |

A `loom-ninja` round is a third route through the same table: build and one
quick probe as subagents, the CI mirror and the merge as scripts, and deep
probe, shape and tidy deferred to its settle-up. See "Fast rounds on a finished
branch" below.

Fix turns happen inside the loop: a must-fix probe finding goes back to
loom-slice in fix mode (the reproduction becomes a failing spec, then a fix),
capped at two turns per probe. A must-fix that survives the cap stops the run
rather than accumulating - loom never carries a known-broken slice forward.

## The structural pass (loom-shape)

Every other stage in this pipeline judges code one file at a time. That misses
one whole class of defect, and it is the expensive one: a unit that is well
named, fully covered, probed and locally excellent while quietly carrying two
ideas at once. Nothing is duplicated, nothing is dead, nothing is misnamed,
every check passes. The bill arrives the next time somebody has to change one
of the two ideas and finds it smeared across eight places.

`loom-shape` asks one question over the whole branch: **does each idea the code
expresses have exactly one home?** It reads and prices; it never edits.

- **It runs after the deep probe and before tidy**, which is the only moment
  the read is both possible and still cheap. Earlier and the shape is still
  moving. Later and the gate has measured a shape nobody looked at, and the
  fix is a second PR.
- **The evidence is the tells**, not taste: a mode flag tested in three files
  or passed down two levels, a comment spending a paragraph on what a member
  means "while paging" versus "while scrolling", members no given caller can
  ever reach, two vocabularies in one type, one predicate tested on eight
  sites. One tell is a question. Two on the same unit is a finding.
- **The bar is deliberately hard to clear.** The concept must already exist
  twice in shipped code, never for a hypothetical third. The smear is listed
  exhaustively by `path:line`. The finding is argued by pricing two or three
  realistic next changes, in files named. It carries a staged plan where every
  stage compiles and passes alone, the behaviors that must survive, an honest
  cost including the test bill, and the strongest case against doing it at all.
  A finding that cannot be staged is a rewrite, and it says so and stops.
- **One reshape per run.** The top finding is executed as a `loom-slice`
  reshape turn, so the finder and the fixer are still never the same agent.
  Everything else is a named follow-up with its sites, which is a story rather
  than scope creep here.
- **What makes an unattended reshape safe** is the budget it has to clear:
  every stage green on its own, no stage editing behavior, no spec assertion
  weakened or deleted, the test count no lower after than before, one mutation
  per seam introduced, and nothing reaching outside the branch's subsystem. A
  plan failing any of those becomes a follow-up instead. It adds no ask moment
  in either mode - a reshape needing permission is one that failed the budget.

The plan already does the cheap half of this before any code exists: its shape
check counts the copies a new pattern adds, prices a widening of a shared unit,
and refuses a mode that cannot name two cases shipping today. What it cannot do
is see the shape the code actually landed in, which is what this stage is for.

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

## Finishing a prototype (loom-finish)

The other way in. `/loom` starts from a request; `/loom-finish` starts from
code that already works, which is what you have after a `/prototype` session.
The difference from backfilling a suite over finished code is where the tests
come from.

```
/prototype ...          # rough it in, click it, iterate
/loom-finish            # bake it in
```

`loom-adopt` reads the uncommitted diff as the spec, separates the behavior it
demonstrates from the gaps it skipped, writes the patch to
`artifacts/loom/<slug>/round-N.patch`, verifies the patch replays, and only then
stashes the tree. With the code out of the way the specs go genuinely red, so
the born-red proof survives intact rather than degrading to an after-the-fact
mutation check. Then the normal stages run unchanged: slice, probe, shape,
tidy, gate, land.

Three things it does differently:

- **No worktree.** It runs in place, on the branch you are standing on, so a
  prototype round after a finished loom run does not need a second workspace.
  `loom-adopt` still refuses the read-only default checkout and `main`.
- **Rounds.** Run it again after the next round of prototyping and it appends
  `## Round 2` to the same ledger. Probe deep, tidy and gate are branch-scoped,
  so a later round re-covers the earlier ones. Land regenerates one report over
  the whole branch.
- **Reconcile.** After the slice loop, adopt runs again and diffs the stash
  against the rebuilt branch. Every prototype hunk is present, deliberately
  dropped with a record, or a miss that goes back as a fix turn. Without it,
  "the rebuild quietly lost a behavior you liked" is invisible until you click
  the app again, and that is the one thing that would make handing your working
  prototype to a pipeline unwise.

The ceremony it cuts, against a normal patch-lane run: scout's workspace setup
and recon (the diff and its neighbors are the recon), `loom-plan` (the diff
supplies each slice's Touches for free), and both ask moments (you approved the
shape by clicking it). The only planned pause is when the diff touches a realm
BFF, because a browser contract is a design decision a diff cannot approve for
itself. Probe deep and shape both stay: they are the review stages and both
read the whole branch. Shape earns its slot here more than anywhere, because
`prototype` is told to reuse and forbidden to refactor, so a second idea moving
into a unit that had one is exactly what a prototype leaves behind.

Be honest about the saving. Measured on a four-slice round, probe and the fix
turns it caused were over half the active time and the gate under four
percent; the gate is a fixed cost of a few minutes that a one-slice patch
still pays in full. None of this touches either, so this is a shorter path,
not a different order of magnitude. The bigger win is that you stop re-deciding a design you
already settled by clicking it.

**Your prototype is never deleted.** The patch is on disk, the stash ref is in
the ledger, and no skill drops either. If a round blocks, the blocker message
carries both.

## Fast rounds on a finished branch (loom-ninja)

The third way in. `/loom` starts from a request, `/loom-finish` from a working
prototype, and `/loom-ninja` from a branch that already landed a full round and
now needs one more small thing.

```
/loom-ninja make the empty state read "No rules yet"
/loom-ninja --refactor          # no behavior change; reshape discipline
/loom-ninja                     # a dirty tree is the request
/loom-ninja --settle            # pay the accumulated review debt, then land
```

It exists because of a measurement. The six ui-app CI checks cost 4:47
sequential and 3:24 in three parallel lanes, while a finished patch-lane round
on a two-file tweak took 54:52 with the gate only 5:37 of it. **The checks are
cheap and the stages are expensive**, so ninja keeps every check and removes
stages: two subagents where loom runs nine, the gate run as a script rather
than delegated, and the merge scripted with an agent only where a conflict
needs semantics. About twenty minutes instead of about fifty-five.

The one thing it defers is the three branch-scoped review passes - probe deep,
shape and tidy - which on a fourth tweak re-read code nothing has touched since
they last cleared it. Ninja records that as **review debt** in the ledger
header and `--settle` pays it in one pass scoped to the accumulated delta, so
the review is amortized rather than skipped. The debt line is reported every
round, in the ledger, the appended report and the closing message. It warns and
never blocks, which makes reporting it loudly the whole mitigation.

Its licence is one fact, checked by script and not by judgment: **the branch's
last loom round landed.** Land is only marked `[x]` after a gate was accepted,
so it is the single line proving the review tail really ran over this branch.
No ledger, or a round still open, and ninja declines and points at `/loom --in`
or `/loom-finish`.

What it will not take: a new BFF route (a browser contract is loom's ask moment
2), a new page or route, new shared state, or more than about three production
files. Its build stage runs that guard before writing anything and bounces in
about two minutes, because building the wrong shape costs a round and a revert.

Born red still holds in the two modes that add behavior. In adopt mode, where
the human hand-tweaked the tree, ninja does not revert: specs are written
against the diff and proved by a targeted mutation instead. That is the one
place its proof is weaker than loom's, and it buys back `loom-adopt`'s patch,
stash, gap sweep and reconcile, about eleven minutes that exist only to make
reverting somebody's working code safe.

## Context economics (why a long run does not drown)

Every stage runs in a fresh subagent, so the expensive noise - file reads,
test output, diffs, upstream source reading - dies with the stage that made
it. What survives is the flight ledger, and the ledger is state, not a log:
evidence lines are one line each, and anything longer (a failing suite, a
conflict listing) goes to a sidecar file under `artifacts/loom/<slug>/` with the
path in the ledger. A return has a fixed shape - one line per unit of work
plus a verdict line - so it cannot grow, and mid-run a stage is verified by
reading only that stage's ledger section, never the whole file. Only land
reads the full ledger, once, in its own fresh context, to write the report.

The slice loop gets one more layer, because it is the part that repeats.
`loom-crew` runs a wave of slices - four by default - and returns one line
each, so the orchestrator grows per wave rather than per slice: it never sees
a slice seed, a stage return, or a slice's ledger section. On a 2-to-6-slice
feature that is one or two waves and the saving is small. It is there for the
long branch - a `loom-finish` run on its fourth round, a plan that sliced into
double figures - where growing per slice is what eventually fills a window.
A crew can also return early and hand the rest to a fresh one, so a wave that
turns out heavy costs one extra line instead of a summarized orchestrator. If a very long run gets its orchestrator context summarized anyway,
nothing is lost: the ledger on disk is the authoritative state and the run
re-grounds from it, which is the same mechanism that makes a killed run
resumable.

## Model economics (why the stages are not all on one model)

Each stage has its own agent type under `~/.claude/agents/`, and its model and
effort live in that file rather than in the orchestrator's judgment. The full
table is in `skills/shared/loom-contract.md`; the rule behind it is one line:
**downgrade by frequency, never by stakes.**

A stage that runs four to twelve times per run and executes a list somebody else
already wrote is where efficiency lives. So the per-slice quick probe is on
sonnet - it runs the Attack line the plan wrote for it - and so is `loom-crew`,
which reads no source and gates against an enumerated checklist. A stage that
runs once and produces a claim nobody can check from outside is the opposite
case, and gets more rather than less: `loom-shape` is the most expensive agent
in the pipeline because its own failure mode is answering an easier question
than the one asked, once per run, with nothing downstream that would catch it.
Everything that writes code or judges evidence stays on opus.

Two stages are split for this reason alone. `loom-probe` has two agent types,
`loom-probe-quick` and `loom-probe-deep`, because the depths are different jobs
at the same desk and one of them runs per slice while the other runs once.
`loom-land` hands each conflicted file to `loom-merge-conflict`, because the
merge around it is mechanical and the resolution inside it is not.

The reason this is agent types and not a `model` argument: a spawn that names
neither inherits the model of whoever spawned it. `loom-crew` and `loom-land`
both sit below the stages they spawn, so a bare spawn from either would quietly
drop the code-writing or conflict-resolving stage a tier - green checks, nothing
in the ledger, no way to tell afterwards. Pinning the model in the agent file
makes that unrepresentable.

## Using the stages standalone

Each stage is a normal skill and useful alone:

- `/loom-probe` - "try to break this branch". The adversarial pass on
  anything, loom-built or not.
- `/loom-gate` - "will CI pass" for ui-app and the BFFs. The local mirror in
  one shot.
- `/loom-shape` - "is this the right shape". The concept-level read, and the
  price of the reshape it recommends.
- `/loom-tidy` - the maintainability pass with the over-engineering veto.
- `/loom-slice` - hand it one small verifiable change and it will build it
  checks-first.
- `/loom-land` - merge main, push, and write the report for a finished
  branch.
- `/loom-adopt` - turn working changes into a slice list and get them out of
  the tree, without running the rest of a round.

`loom-ninja` adds two scripts that are useful on their own:
`skills/loom-ninja/scripts/gate.sh <slug> origin/main <round base>` is the
whole ui-app CI mirror in three parallel lanes with a scorecard, and
`skills/loom-ninja/scripts/debt.sh` reports a branch's loom state and how much
of it no review pass has covered.

Standalone runs still read `skills/shared/loom-contract.md`, which is the
single place the repo facts (commands, coverage gate, translation rules, git
rules, hard stops) live. Change a fact there and every loom skill follows.

## Where loom ends

loom stops at a pushed (or deliberately local) branch plus its report. It
never creates a work item, never opens a PR, never deletes a worktree:

- `/paperwork` reads the loom report and files the TFS item and the PR.
- `/teardown` sweeps the worktree after the merge.
- `/loom-finish` picks the branch back up for the next round of changes,
  in place, without opening a second run.

loom assumes the request is roughly right and optimizes how it gets built, so
it does not answer what to build. For a genuinely open design question, run
`ux-review` first, then loom the approved shape.

## Why it is built this way

- **Lanes instead of one path.** The smallest honest route through the old
  pipeline it replaced was five stages; loom's patch lane is brief, build,
  probe, gate, land.
- **Tests are born, not backfilled.** A suite written after the fact has to
  mutation-check every test to prove it could fail. loom's checks are written
  first and observed red, which is the same proof for free, at the moment it
  is cheapest.
- **Probe replaces the review fan-out.** Four concurrent read-only reviews
  plus triage becomes one executing skeptic per slice plus one deep pass -
  fewer agents, findings that are reproductions instead of opinions, and the
  fixes happen while the slice is still in context.
- **Structure gets a stage, not a wish.** The defect that survives every local
  check is a concept with two homes, and no amount of per-file review finds it.
  It gets its own pass with its own bar, and a budget to actually fix one
  rather than only writing it down.
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
  bff-platform, another C# service, or infra gets loom for the parts it owns,
  and the gate says explicitly which components it did not cover.
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
