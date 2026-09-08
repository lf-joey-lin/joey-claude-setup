---
name: loom
description: Orchestrate a full loom run - a slice-based dev pipeline for momentum ui-app work (including the acs-bff/app-bff route a slice needs, built through api-integrator) that builds one verifiable increment at a time, checks-first, with an adversarial probe after every slice and a flight ledger recording every claim with its evidence. Attended by default with exactly two ask moments; --solo runs unattended end to end without pushing. Invoke when the user types /loom <request>, or asks to "loom this", "run loom on <feature>", or wants a ui-app change built through the loom pipeline.
---

# loom: the orchestrator

Take a request for `ui-app` work and drive it to a finished branch: sliced,
built checks-first, probed, tidied, gated, merged with main, and explained in
a report generated from evidence. You are the **conductor, not a worker**: you
spawn one subagent per stage, gate each on the evidence it wrote into the
flight ledger, and never read source or write code in your own context. If you
catch yourself doing either, stop and delegate.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) before
anything - the ledger format, the attendance contract, the repo facts, and the
nesting rules there are the law of the run.

## Invocation

```
/loom <request>              # attended: two ask moments, push confirmed
/loom <request> --solo       # unattended: zero asks, never pushes
/loom <request> --no-push    # attended, but land leaves the branch local
/loom <request> --in <dir>   # run in a worktree the human already made
```

`<request>` is required - a sentence or a short bullet list. State the
resolved shape in your first line of output, before any tool call:
`Mode: attended | solo   Slug: <slug>   Round: <n>`.

**Resume**: if `artifacts/loom/<slug>-ledger.md` already exists (check the
default worktree and `<root>/momentum-<slug>`), read it and continue from the
first stage not `[x]`. Never restart a done stage, never open a second
workspace for the same slug.

**`--in <dir>`**: scout adopts that worktree instead of creating one, and
`<slug>` becomes its branch name rather than anything derived from the
request. It is what lets a second and third request land on a branch the human
already opened, one queue per worktree (`shell/mqueue.sh` in
`joey-claude-setup` drives this). Two things change for you as conductor:

- **The run is a round.** Scout reports the round number. On a round after the
  first, every stage of this run nests under `## Round <n>` in the one ledger
  the branch already has, exactly as `loom-finish` does, and every stage seed
  carries the round number alongside the ledger path. Slice ids carry the
  round prefix (`R2.S1`). A finished round is history, never a resume point.
- **Branch-scoped stages read the whole branch.** Probe deep, shape, tidy, gate
  and land cover every round on the branch, not just this one, so an earlier
  round's code is re-covered rather than assumed good. That is the point of
  them being branch-scoped. Shape especially: a concept splits across rounds,
  and the round that puts the second tenant in is the one that can see it.

## The run

Every stage is one synchronous subagent, spawned by the agent type the
contract's "Models" section names for it and seeded per its delegation section
(worktree path, ledger path, mode line, read the contract plus its own skill
file). Gate each stage on the ledger entries it appended - the evidence
lines, never the subagent's prose - by reading **only that stage's section**
of the ledger, per the contract's context-economy rules; never re-read the
whole file mid-run. Record your own gate decision as the last line of that
stage's section (the contract's `- Gate:` line) before moving on. The slice loop is the one
exception: a crew holds those slices and writes their gate lines, and you
never read them (step 3).

1. **Scout** (`loom-scout`). Gate: ledger exists, Brief `[x]`, lane decided,
   branch and worktree named, and under `--in` the round number reported.
   - **Ask moment 1 (attended only)**: present the brief summary - lane,
     decisions taken, open questions - with one `AskUserQuestion`
     (approve / adjust / abort). On adjust, re-seed scout with the feedback;
     the workspace is kept. Solo: skip; scout already defaulted everything or
     blocked.
2. **Plan** (`loom-plan`, feature lane only). Gate: every slice has Behavior,
   Platform, numbered Checks each naming a channel, Touches, Attack. A
   `Platform:` line that is missing, or that hand-rolls with no unit named as
   passed over, fails the gate - send it back once; the sweep is cheap and
   nothing downstream reopens the choice. A bff slice also
   has its Upstream / Route / DTO / Status map fields filled from the real
   legacy source (the contract's "BFF slices" section).
   - **Ask moment 2 (attended only)**: the slice list, one line each, plus
     every hand-roll with the platform unit it passed over, and any custom
     component justification (approve / adjust / abort). When the plan
     has a bff slice, this question also carries its browser-contract design -
     it doubles as api-integrator's approval gate, so show the route, verb,
     DTO cuts, and status map, not just the slice name. This is the last
     planned pause before land.
3. **The slice loop, one wave at a time** (`loom-crew`). You do not run this
   loop - a crew does, in its own context, and hands you one line per slice.
   Spawn a crew seeded per the contract plus a wave size, let it build, probe
   and fix its slices, then spawn the next one. Repeat until the plan has no
   slice left. This is what keeps your own context flat across a long run:
   you grow by a wave, not by a slice.
   - **Wave size**: four slices by default. Size down where the plan drew
     slices wide (a bff slice, one with many checks), up only for a plan of
     small ui slices. A crew may return short and often will; it may never
     return long.
   - **Gate a wave on its return lines**, plus one cheap check: `git log
     --oneline` on the branch shows the green commits it named. A hash that is
     not there is a fabricated claim and fails the wave. Everything the crew
     gated inside the wave (red-before-green per slice, probe reproductions,
     the two-fix-turn cap) is the crew's own gate, recorded in the ledger, and
     you do not re-verify it.
   - **An early return is normal**, not a failure: spawn the next crew, which
     picks up from the first slice not `[x]`. A crew returning BLOCKED stops
     the run, with the ledger heading its wave line names.
   - A patch-lane run has exactly one slice, defined in the brief. Spawn a
     crew for it anyway - one line back is cheaper than the four calls it
     replaces, and the patch lane then has no second code path.
   - You never see a slice seed, a stage return, or a slice's ledger section.
     If you find yourself reading one mid-run, the crew boundary has leaked.
4. **Probe deep** (`loom-probe-deep`, over the whole branch). Same fix-turn
   rule, same cap. It is a different agent type from the quick probes the crew
   ran, because deep is a once-per-run read of everything and quick is a
   per-slice run of a list the plan already wrote.
5. **Shape** (`loom-shape` over the whole branch). The concept-level read: does
   each idea the branch expresses have one home. It finds and prices; it never
   edits. Gate: a concept map exists, every finding carries its complete site
   list and its priced next change, and each one says executable or follow-up
   with the budget rule that decided it. A structural claim with a partial site
   list fails the gate - send it back once.
   - **The reshape turn**, only when a finding came back executable: one
     `loom-slice` in reshape mode, seeded with that finding's staged plan
     verbatim. Gate it on the ledger's `### Reshape` entry: every stage green on
     its own, the test count no lower after than before, one mutation per seam
     introduced, and the must-survive list walked. A stage that could not land
     green means the plan was wrong - the stage is reverted, the finding becomes
     a follow-up, and the run continues; that is a recorded outcome, not a
     blocker. **One reshape per run**, and no second attempt.
   - No re-probe follows a reshape. It changed no behavior, the whole suite plus
     the seam mutations is its evidence, and `loom-gate` measures the result
     anyway.
6. **Tidy** (`loom-tidy`). Gate: fixes committed with slice checks still
   green, follow-ups and vetoes recorded. Tidy reporting a locked-in behavior
   as wrong is a finding for the report, never a change.
7. **Gate** (`loom-gate`). READY: continue. NOT READY: one targeted fix turn
   seeded with the real failing output (loom-slice fix mode for code, nothing
   for what the gate owns itself), re-run the gate once. Still NOT READY:
   stop the run - no push, ledger `[!]`, the output in Blockers. A faked
   pass is the worst outcome this pipeline can produce.
8. **Land** (`loom-land`). Attended: show the report's inline sections, then
   confirm the push with one question (skipped under `--no-push`). Solo: land
   never pushes; the report says so.

After land, point at `/paperwork` for the work item and PR - loom creates
neither, ever. Cleanup after the merge is `/teardown`, on the human's ask.
More work on the same branch afterwards is `/loom-finish`, which adopts the
next round of changes in place rather than opening a second run.

## Blockers and asks

- Outside the two ask moments and the push confirmation, **asking the human is
  a bug in this skill**. A fork with no documented default takes the
  contract's default order, gets logged `(defaulted)`, and the report's
  Decisions section carries it. A genuine blocker (contradictory input, a
  fix-turn cap reached, a NOT READY gate after its retry) stops the run with a
  ledger entry and a `blocked` end-of-run receipt (the contract) - solo and
  attended alike. You write that receipt yourself on a stop; land writes it
  when a run finishes normally. Either way it is the last act of the run.
- Never fork alternatives, never build two versions of a close call: decide,
  log, continue.

## Running several in parallel

Spawn one background `general-purpose` agent per request, each told to invoke
the loom skill with `--solo` and its request. That one is deliberately not an
agent type: it is standing in for you, the orchestrator, so it takes the
session's model like you do. Everything it spawns below itself still goes by
agent type. Scout gives every solo run its
own worktree, so they cannot collide; the ledgers keep them independently
resumable. Review each report in the main session, then push and run
`/paperwork` per branch there.

Note this adds a level above the orchestrator, so such a run is four deep:
background agent, loom, crew, stage. If the runtime refuses to spawn that
deep, the crew is the level to drop - tell the background agent to run the
slice loop inline per the contract's no-subagents fallback. Do not drop a
stage instead; the stages are where the work happens.

Model note: every stage has its own agent type and the model lives in that
file, not in your judgment. Spawn by `subagent_type` and never pass `model`
yourself - the contract's "Models" section is the table and the reasoning.

## Invariants

- The orchestrator owns the gate decisions for the stages it runs itself; the
  crew owns them for the slices in its wave. Every read of source and every
  edit happens in a stage subagent, below them both.
- Gate on ledger evidence (commands, exit codes, red records), never on
  prose, and read it by stage section - the contract's context-economy rules
  are what keep a twenty-round run inside one context window.
- One slice at a time; the pipeline is sequential by design and stages are
  never fanned out across each other. A wave is a context boundary, not a
  parallelism boundary - one crew runs at a time, and its slices run in
  order.
- The bar is identical attended and solo; attendance only changes who answers
  questions and whether land may push.
- The contract's hard stops hold everywhere: secrets, generated catalogs,
  `main`. A stop is reported, never worked around.
- No work item, no PR, no teardown - those are `/paperwork` and `/teardown`,
  on the human's word.
