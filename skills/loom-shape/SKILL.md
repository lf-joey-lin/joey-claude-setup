---
name: loom-shape
description: Structural stage of the loom pipeline - one concept-level read over the finished branch, asking whether each idea the code expresses has exactly one home, and pricing a reshape rather than rejecting it for being big. Finds and prices only; the reshape it recommends is executed as a loom-slice turn. Invoke via /loom normally; directly when the user asks whether a branch is the right shape, should be split, or reads well and still feels like it is doing two jobs.
---

# loom-shape: does each idea have one home

You run once, after the deep probe and before tidy. The behavior is proven by then and
the shape has stopped moving, which is the only moment this read is both possible and
still cheap to act on.

The defect you hunt is the one every other stage is blind to by construction. Read
these two before you act:

1. [`../shared/loom-contract.md`](../shared/loom-contract.md) - the ledger format,
   repo facts, hard stops and delegation rules that bind every loom skill.
2. [`../shared/structural-bar.md`](../shared/structural-bar.md) - **your detector and
   your bar.** The altitude, the pair-discovery frame, the ten tells, the seven-rule
   bar, the not-a-finding list and the assemble rule all live there. Binding, and not
   to be paraphrased from memory.

Then read the ledger's Plan section (it names every unit the branch introduced) and the
deep probe's findings.

This file carries only what is specific to running as a loom stage: the scope, the cap,
the reshape budget, the ledger block and the return.

**You write no product code.** You find, you price, and you draw the staged plan; the
orchestrator runs `loom-slice` in reshape mode over what you return, so the finder and
the fixer are never the same agent here either.

`solidify` is the same detector run outside the pipeline, against a branch with no
ledger. If you are reading this to review a branch by hand, use that instead.

## What is yours, and what is not

The shared bar's altitude section is binding. In this pipeline its two hand-offs are:

- A defect whose evidence fits inside one file is **`loom-tidy`'s**, and it runs
  straight after you. Notice one, put it in a single line under "Local defects noticed"
  with no analysis and no proposal, and move on.
- Functional bugs and security are **the probe's**, and it has already run. Test design,
  component choice, i18n, theming and a11y are nobody's here.

One addition to the shared not-a-finding list, specific to this pipeline:

- **Behavior a slice check locks in.** If the shape is wrong because the behavior is
  wrong, that is a line for the human in the ledger, never a reshape.

## Step 0 - scope

From the worktree root, over the whole branch rather than one round:

```bash
git log origin/main..HEAD --oneline
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
```

The ledger's Plan section already names the units the branch introduced, which is your
input to the pair-up search - use it rather than re-deriving the list from the diff.

Then run the shared bar's discovery: **pair up, then diff the pair.** Its three searches
(same folder, other consumers of something shared the unit imports, vocabulary), its
frame rule (full reads limited to the branch's units plus each pair's sibling), its axis
check over the branch's own units, its declaration-level check on shared contracts, and
its one escalation to a per-caller matrix when a flag sits on a public type with more
than about three consumers.

Read specs as **evidence and never review them** - a spec that splits by a mode the
source does not is one of the strongest tells there is, and its design is still tidy's
business, not yours.

**Run it in your own context, one phase at a time, finishing each before opening the
next. Do not spawn subagents; a stage spawns nothing.** The contract's depth limit ends
at you.

## Step 1 - assemble, apply the bar, cap at one

Assemble per the shared bar, then apply its seven rules to the assembled finding.

**Cap the actionable list at one.** The branch gets one reshape, so the finding that
makes the most likely next edit cheapest is the one you plan in full. Everything else is
recorded as a follow-up with its site list, honestly, so it becomes its own story rather
than scope creep here.

A subsystem showing three or more structural findings is one you have misjudged or one
that needs a design conversation rather than a stage: say which, plan none of them, and
let the report carry it.

## Step 2 - the reshape budget

The one finding is **executed** only when the plan you drew clears all of these. This is
what makes an unattended reshape defensible, so check it literally rather than in
spirit.

- **Staged**, and every stage compiles, lints and passes the whole unit suite on its own
  (bar rule 5).
- **Every stage is a move, a rename, a split or a seam introduction.** No stage edits
  behavior. A reshape needing a behavior change to work is a follow-up.
- **No spec assertion is weakened, deleted or loosened.** Specs may move, may be
  re-imported, may be split across files. The test count after must be at least the count
  before, and the reshape's evidence line carries both numbers.
- **It stays inside the frame**: the files the branch touched, the units it introduced,
  and each pair's sibling. A migration reaching wider than that is a follow-up however
  good it is.
- **It touches no behavior a slice check locks in** (the contract's rule, and the reason
  the suite staying green is a real gate rather than a formality).

Anything failing one of these is recorded as a follow-up, named, with the rule that
stopped it. That is a legitimate and common outcome. **A clean pass is also a legitimate
outcome**: say it plainly, with the cleared list behind it, so a reader can tell a real
pass from a skipped one.

Bar rule 6's **must survive** list names the slice check that locks each behavior, since
in this pipeline those checks exist and can be pointed at.

The bar is identical attended and solo. Nothing here asks the human anything - the run's
ask moments are both behind you, and a reshape that needs permission is one that failed
the budget above.

## The ledger

Append `## Shape - [ ]` (or `### Shape` inside a round), with your own `- Timing:` line,
and fill:

```markdown
## Shape - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Pairs: <branch unit> vs <sibling> (found by <search>) - <lined up | diverged at row n>
- Frame: read <n> files in full; escalations paid: <type, consumers> | none
- Cleared: <central unit or pair> - <why it is structurally fine>, one line each
- Could not reach: <the shared bar's blind spots, as they apply here>
### Finding S1 - <concept in one noun phrase>
- Severity: structural | drifting | note
- Smear: <the part-by-part table, every site by path:line>
- Tells: <which fired, with the quoted comment, the empty rectangle, the count>
- Price: change <X> touches <files, named> today, <files> after
- Target shape: <type signatures, file names, component boundaries>
- Stages: 1 <what lands, green how> 2 ... (each compiling and passing alone)
- Must survive: <behavior> - locked by <slice check>
- Cost: <files added, files touched, specs split, net line direction, test bill>
- Case against: <the strongest argument for leaving it alone>
- Budget: executable | follow-up - <the rule that stopped it>
- Follow-ups: <finding> - <sites> - <why it is not this branch's>
- Local defects noticed: <one line each, no analysis> - owner loom-tidy
```

## Return

The contract's fixed shape: one line per finding, then a verdict line. Nothing else - the
ledger carries the detail and land reads it in its own context.

```
S1 STRUCTURAL | how a listing reads its next rows, 8 sites 3 files, executable in 5 stages | ledger:### Finding S1
S2 NOTE | what a row gesture is policed by, rewrite not stageable, follow-up | ledger:### Finding S2
SHAPE done | 1 executable, 1 follow-up, 4 pairs cleared | ledger:## Shape
```

A clean pass returns the verdict line alone:

```
SHAPE done | 0 findings, 6 pairs cleared, 11 files read in full | ledger:## Shape
```

## Invariants

- You read and price. You never edit product code, never fix, and never write a spec.
  The reshape is `loom-slice`'s in reshape mode, seeded with your staged plan.
- The shared bar is the detector and the gate. Do not re-derive it, do not soften it,
  and do not widen the frame it sets.
- Concepts only. A defect whose evidence fits in one file is tidy's, and goes back in one
  line without analysis.
- Bar rule 1 does not bend: two shipping cases or it is not a finding.
- One reshape per run. Everything else is a named follow-up.
- One agent, phases in order, spawn nothing.
- No new ask moment, in either mode. The budget decides, not the human.
- The contract's hard stops hold: secrets, generated catalogs, `main`.
