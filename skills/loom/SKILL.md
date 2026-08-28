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
```

`<request>` is required - a sentence or a short bullet list. State the
resolved shape in your first line of output, before any tool call:
`Mode: attended | solo   Slug: <slug>`.

**Resume**: if `src/ui-app/logs/loom/<slug>.md` already exists (check the
default worktree and `<root>/momentum-<slug>`), read it and continue from the
first stage not `[x]`. Never restart a done stage, never open a second
workspace for the same slug.

## The run

Every stage is one synchronous subagent, seeded per the contract's delegation
section (worktree path, ledger path, mode line, read the contract plus its own
skill file). Gate each stage on the ledger entries it appended - the evidence
lines, never the subagent's prose - by reading **only that stage's section**
of the ledger, per the contract's context-economy rules; never re-read the
whole file mid-run. Record your own gate decision in the ledger before moving
on.

1. **Scout** (`loom-scout`). Gate: ledger exists, Brief `[x]`, lane decided,
   branch and worktree named.
   - **Ask moment 1 (attended only)**: present the brief summary - lane,
     decisions taken, open questions - with one `AskUserQuestion`
     (approve / adjust / abort). On adjust, re-seed scout with the feedback;
     the workspace is kept. Solo: skip; scout already defaulted everything or
     blocked.
2. **Plan** (`loom-plan`, feature lane only). Gate: every slice has Behavior,
   numbered Checks each naming a channel, Touches, Attack; a bff slice also
   has its Upstream / Route / DTO / Status map fields filled from the real
   legacy source (the contract's "BFF slices" section).
   - **Ask moment 2 (attended only)**: the slice list, one line each, plus any
     custom component justification (approve / adjust / abort). When the plan
     has a bff slice, this question also carries its browser-contract design -
     it doubles as api-integrator's approval gate, so show the route, verb,
     DTO cuts, and status map, not just the slice name. This is the last
     planned pause before land.
3. **The slice loop.** For each slice in order (a patch-lane run has exactly
   one, defined in the brief):
   - `loom-slice` (bff mode when the slice's Kind is bff). Gate: a red record
     exists for every check, a green commit exists, the slice's cheap verify
     lines report exit 0 (typecheck and eslint for ui; the BFF build and test
     class for bff). A slice summary claiming green with no red evidence in
     the ledger fails the gate - send it back once; twice is a blocker.
   - `loom-probe` quick, scoped to the slice. Gate: findings carry
     reproductions and severities, probe specs are cleaned up or flagged
     promote.
   - **Fix turn**, only if probe returned must-fix findings: one `loom-slice`
     in fix mode seeded with the findings verbatim, then one `loom-probe`
     re-check scoped to those findings. At most two fix turns per probe;
     a must-fix still open after that is a blocker - stop, do not accumulate
     known-broken slices. Polish findings are recorded and carried, not fixed
     mid-loop.
4. **Probe deep** (`loom-probe` over the whole branch). Same fix-turn rule,
   same cap.
5. **Tidy** (`loom-tidy`). Gate: fixes committed with slice checks still
   green, follow-ups and vetoes recorded. Tidy reporting a locked-in behavior
   as wrong is a finding for the report, never a change.
6. **Gate** (`loom-gate`). READY: continue. NOT READY: one targeted fix turn
   seeded with the real failing output (loom-slice fix mode for code, nothing
   for what the gate owns itself), re-run the gate once. Still NOT READY:
   stop the run - no push, ledger `[!]`, the output in Blockers. A faked
   pass is the worst outcome this pipeline can produce.
7. **Land** (`loom-land`). Attended: show the report's inline sections, then
   confirm the push with one question (skipped under `--no-push`). Solo: land
   never pushes; the report says so.

After land, point at `/paperwork` for the work item and PR - loom creates
neither, ever. Cleanup after the merge is `/teardown`, on the human's ask.

## Blockers and asks

- Outside the two ask moments and the push confirmation, **asking the human is
  a bug in this skill**. A fork with no documented default takes the
  contract's default order, gets logged `(defaulted)`, and the report's
  Decisions section carries it. A genuine blocker (contradictory input, a
  fix-turn cap reached, a NOT READY gate after its retry) stops the run with a
  ledger entry - solo and attended alike.
- Never fork alternatives, never build two versions of a close call: decide,
  log, continue.

## Running several in parallel

Spawn one background `general-purpose` agent per request, each told to invoke
the loom skill with `--solo` and its request. Scout gives every solo run its
own worktree, so they cannot collide; the ledgers keep them independently
resumable. Review each report in the main session, then push and run
`/paperwork` per branch there.

Model note: stages that think (plan, slice, probe deep, tidy) belong on the
session's default model; scout, gate, and land are mechanical enough for a
cheaper tier when spend matters. No fixed table - pass `model` per Agent call
as judgment dictates.

## Invariants

- The orchestrator owns the ledger's gate decisions and nothing else; every
  read of source and every edit happens in a stage subagent.
- Gate on ledger evidence (commands, exit codes, red records), never on
  prose, and read it by stage section - the contract's context-economy rules
  are what keep a twenty-round run inside one context window.
- One slice at a time; the pipeline is sequential by design and stages are
  never fanned out across each other.
- The bar is identical attended and solo; attendance only changes who answers
  questions and whether land may push.
- The contract's hard stops hold everywhere: secrets, generated catalogs,
  `main`. A stop is reported, never worked around.
- No work item, no PR, no teardown - those are `/paperwork` and `/teardown`,
  on the human's word.
