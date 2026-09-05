---
name: loom-finish
description: Bake a working prototype into a finished branch, in place, using the loom pipeline - adopt the uncommitted (or named) changes as the spec, revert them so the specs can be born red, rebuild slice by slice, probe, tidy, gate, merge main and push, with a report generated from the flight ledger. Creates no worktree and can run repeatedly on the same branch. Invoke when the user types /loom-finish, or asks to "finish this off", "bake this in", "make my prototype real", or "wrap this up the loom way".
---

# loom-finish: the orchestrator for baking a prototype in

A human prototyped something and clicked it. Your job is to turn that into a
branch that ships: tested with checks that were seen failing, attacked,
tidied, gated, merged with main, and explained from evidence. You are the
**conductor, not a worker** - one subagent per stage, gated on what it wrote
into the flight ledger, and you never read source or write code in your own
context.

The difference from backfilling a suite over finished code is where the tests
come from. Backfilling has to mutation-check every test afterwards to prove it
can fail. `loom-finish` takes the prototype out of the tree first, so the specs go genuinely red and
the proof happens at birth, which is the same proof for free.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) before
anything - the ledger format, the repo facts, the delegation and
context-economy rules there are the law of the run.

## Invocation

```
/loom-finish                    # adopt the uncommitted work, push confirmed
/loom-finish --from <ref>       # adopt a commit, a range, or `branch`
/loom-finish --solo             # zero asks, never pushes
/loom-finish --no-push          # land leaves the branch local
```

No request argument: the diff is the request. State the resolved shape in your
first line of output, before any tool call:
`Mode: attended | solo   Round: <n>   Source: <uncommitted | ref>`.

**No worktree, ever.** This runs where the session is standing. `loom-adopt`
refuses the read-only default checkout and refuses `main`; those are the only
workspace guards the round needs.

**Rounds, not resumes.** A branch that already finished a loom run or an
earlier round has a ledger with those sections at `[x]`. Do not resume them
and do not start a second ledger: append `## Round <n>`, numbering from the
highest round already present. An *incomplete* round is a resume in the normal
sense - continue from its first stage not `[x]`.

## The round

Every stage is one synchronous subagent, seeded per the contract's delegation
section: the absolute worktree path, the ledger path, the round number, the
mode line, and the instruction to read the contract plus its own skill file.
Gate each stage on the ledger entries it appended - the evidence lines, never
the prose - reading **only that stage's subsection of this round**. Record
your own gate decision as the last line of that subsection (the contract's
`- Gate:` line) before moving on.

1. **Adopt** (`loom-adopt`). Gate: the patch exists and its `--check` passed,
   the stash ref or pre-reset SHA is recorded, every behavior names a channel,
   every gap has an owner, and the slice list is written.
   - **Contract gate, only when the round has a bff slice**: one
     `AskUserQuestion` carrying the route, verb, DTO cuts and status map
     (approve / adjust / abort). This is api-integrator's Step 5 and it is the
     only planned pause in the whole round. Solo logs the design in full
     instead.
   - Any other ask is a bug in this skill. The human already approved the
     shape by clicking the prototype; that is what makes this path short.

2. **The slice loop, one wave at a time** (`loom-crew`). A crew runs the loop
   in its own context and returns one line per slice; spawn crews until the
   round's plan has no slice left. Seed each with the round's slice ids (they
   carry the round prefix) and the two things a round adds on top of the
   contract, for it to pass down:
   - **To every `loom-slice`, one extra instruction**: write the specs and see
     them red *before* opening the round patch. The patch is the green step's
     reference, not the spec's. An agent holding the implementation writes
     specs to the implementation, and the whole reason the tree was reverted
     is to avoid that.
   - **To every `loom-probe`, the gaps adopt assigned to probe**, added to its
     attack list.

   Gating, wave size, early returns and blockers are as `loom` describes them:
   the crew's return lines plus `git log --oneline` for the commits it named,
   four slices by default, an early return means spawn the next crew, BLOCKED
   stops the round.

3. **Reconcile** (`loom-adopt`, reconcile mode). Gate: every prototype hunk is
   present, dropped with a record, or reported as a miss. Each miss goes back
   as a `loom-slice` fix turn under the same two-turn cap.
   This is the step that makes reverting a human's working code safe. Do not
   skip it, and do not accept a reconcile that reports counts without naming
   what it compared.

4. **Probe deep** (`loom-probe` over the whole branch, not just this round).
   Same fix-turn rule, same cap. On a later round the branch includes earlier
   rounds, which is the point: deep is branch-scoped and re-covers them.

5. **Tidy** (`loom-tidy`). Gate: fixes committed with slice checks still green,
   follow-ups and vetoes recorded. Worth its slot here more than on a normal
   run: `prototype` is told to reuse but forbidden to refactor, so a second way
   to do an existing thing is exactly what a prototype leaves behind.

6. **Gate** (`loom-gate`). READY: continue. NOT READY: one targeted fix turn
   seeded with the real failing output, re-run the gate once. Still NOT READY:
   stop the round - no push, ledger `[!]`, the output in Blockers.

7. **Land** (`loom-land`). Merge `origin/main`, re-gate if it brought anything,
   push when allowed, regenerate the report from the **whole** ledger so it
   covers every round rather than this one. Seed it with whether the branch
   already has an upstream - it cannot assume scout published one here.
   Attended: show the report's inline sections, confirm the push with one
   question (skipped under `--no-push`). Solo: never pushes.

After land, report the stash ref and the patch path back to the human and say
they are still there. **Never drop the stash yourself.** Then point at
`/paperwork` for the work item and PR. Cleanup is `/teardown`, on their ask.

## Blockers and asks

- Outside the bff contract gate and the push confirmation, asking the human is
  a bug. An open question takes the contract's default order and gets logged
  `(defaulted)`.
- A genuine blocker stops the round with a ledger entry: contradictory input, a
  fix-turn cap reached, a reconcile miss that two turns could not close, a gate
  still NOT READY after its retry, a patch that failed `--check`.
- **A blocker never means the prototype is gone.** Report the stash ref and the
  patch path in the same message as the blocker, every time.

## Invariants

- The orchestrator owns the round's gate decisions and nothing else.
- Gate on ledger evidence, by round subsection, never on prose or on memory.
- One slice at a time; stages are never fanned out across each other.
- The bar is identical attended and solo. Attendance changes who answers the
  bff question and whether land may push.
- The contract's hard stops hold: secrets, generated catalogs, `main`, the
  read-only default worktree. A stop is reported, never worked around.
- The prototype survives the round in two places until the human says
  otherwise. Reverting their work is only defensible because it is recoverable
  and because reconcile proves the rebuild kept it.
- No work item, no PR, no teardown, no worktree.
