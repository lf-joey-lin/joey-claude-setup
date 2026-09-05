---
name: loom-land
description: Final stage of the loom pipeline - merge the latest origin/main into the branch, re-gate if the merge changed anything, push when allowed, and generate the human-facing report from the flight ledger. Invoke via /loom normally; directly to "land" a finished loom branch.
---

# loom-land: merge, push, report

You finish the run: the branch ends up containing current `origin/main`, on
the remote when the mode allows, with a report a reviewer can read before
opening the diff. Read
[`../shared/loom-contract.md`](../shared/loom-contract.md) first.

## Step 1 - merge origin/main

Merge, never rebase - the branch was published at scout. `git fetch origin`,
then `git merge-base --is-ancestor origin/main HEAD` - already an ancestor
means record "up to date" and skip to step 3.

Otherwise `git merge --no-edit origin/main`. Conflicts:

- Generated catalogs (`fr.json`, `es.json`, `en-XA.json`, XLIFF) take main's
  side (`git checkout --theirs`) - the pipeline regenerates them. `en.json`
  is source and is resolved by hand.
- Lockfiles take main's side, then re-run the install to regenerate.
- Everything else: one subagent per conflicted file (the one fan-out this
  pipeline's stages are allowed), each seeded with the absolute worktree
  path, its file, what the branch is doing, and the bar: both sides' intent
  survives, no side taken wholesale, no markers or commented-out losers left,
  one line per hunk on how both survived.
- **Stop, do not guess**, when the sides genuinely disagree about behavior:
  `git merge --abort`, ledger entry with the file and what each side does.
  That is a human call.

Grep resolved files for leftover markers, `git commit --no-edit`.

## Step 2 - re-gate if the merge brought anything

A merge can conflict nowhere and still break the branch. If step 1 merged
commits in, re-run `loom-gate`'s check set (inline - you are the stage). A
NOT READY here stops the run with the output; do not push a branch the gate
just failed.

## Step 3 - push, or not

- **Attended**: the orchestrator has confirmed the push before seeding you,
  or passes `--no-push`; do what the seed says. `git push` (upstream exists
  from scout; `git push -u origin HEAD` if not).
- **Solo**: never push. The branch stays local; the report says so and gives
  the one command.
- A rejected push is reported with the real error and the commits left in
  place - never pull-rebase or force to get past it.

## Step 4 - close the clock

Read `date -Iseconds` now, before writing a word of the report, and put it in
the ledger header's `Finished:`. **The run's finish is the moment the report
starts being written**, because a report cannot time its own writing. Then
fill the header's two totals, both from the shell, never by hand:

- `Wall:` header `Started:` to header `Finished:`.
- `Active:` every stage's `- Timing:` line summed, fix turns and re-probes
  included.

They differ by the orchestrator's gating between stages, and on a resumed run
they differ by however long the run sat idle. That gap is the point of
carrying both, so never report one as the other, and never quietly reconcile
them. If a stage's timing line is missing, say so in the report and leave it
out of `Active:` rather than estimating it - a made-up duration is worse than
an admitted hole.

## Step 5 - the report, from the ledger

Write `artifacts/loom/<slug>-report.md` **from the ledger, not from
memory** - every claim in the report must trace to a ledger entry with
evidence. Under the title, one line: the branch, and
`started <iso>, finished <iso>, wall <hh:mm:ss>, active <hh:mm:ss>`.
Structure:

1. **What this branch does** - two or three sentences in user terms.
2. **The slices, in order** - one short block each: the behavior, the commit,
   the checks that lock it in (born red, per the ledger), and the slice's
   started, finished and took, copied from its `- Timing:` line.
3. **What probe found and what happened to it** - each finding with its
   reproduction in one line, fixed-in-commit or deferred-with-reason.
   Promoted probe specs named: these are the regression tests the run earned.
4. **Tidy** - fixes applied, follow-ups recorded, vetoed items in one line
   each.
5. **The gate scorecard**, verbatim, plus what CI still owns.
6. **Needs human eyes** - only what genuinely cannot be asserted: visual
   polish, subjective UX feel, real-backend behavior. Each with the route,
   state, and breakpoint to look at (`npm run dev` from `src/ui-app`). If any
   `en.json` changed, the `to-be-translated` note per the contract.
7. **Decisions taken** - everything marked `(defaulted)` in the ledger, so
   the reader sees what was assumed versus asked.
8. **Timing** - a table, one row per stage in the order they ran, slices and
   fix turns and probes alike: stage, started, finished, took. Then the two
   totals from the header, labelled as step 4 defines them. Copy every cell
   from a `- Timing:` line; compute nothing here. Keep it factual - it is a
   record of where the run spent itself, not a performance claim, so do not
   editorialise about which stage was slow.
9. **Next step** - one line: `/paperwork` for the work item and PR (it reads
   this report), or the push command if the branch is still local.

Present sections 1, 5, and 6 inline in the conversation, plus the two totals
from section 8 as one line; point at the file for the rest. Mark Land `[x]`
in the ledger with the merge result, push state, report path, and its own
`- Timing:` line.

Then write the end-of-run receipt (the contract, "The end-of-run receipt") as
the last thing you do, `landed` with the round and the push state. A queue
picks the next run up off that line, so a run that skips it looks stuck.
