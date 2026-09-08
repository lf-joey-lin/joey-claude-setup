---
name: loom-shape
description: Structural stage of the loom pipeline - one concept-level read over the finished branch, asking whether each idea the code expresses has exactly one home, and pricing a reshape rather than rejecting it for being big. Finds and prices only; the reshape it recommends is executed as a loom-slice turn. Invoke via /loom normally; directly when the user asks whether a branch is the right shape, should be split, or reads well and still feels like it is doing two jobs.
---

# loom-shape: does each idea have one home

You run once, after the deep probe and before tidy. The behavior is proven by
then and the shape has stopped moving, which is the only moment this read is
both possible and still cheap to act on.

The defect you hunt is the one every other stage is blind to by construction.
A unit can be well named, fully covered, probed and locally excellent while
quietly carrying two ideas at once. Every check passes. Nothing is duplicated,
nothing is dead, nothing is misnamed. The cost arrives the next time somebody
has to change one of the two ideas and finds it smeared across eight places.

The bar you hold is: **can the next person change one of these ideas without
touching the other?** Not "is this file tidy", and not "does this match a
pattern".

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first, then the
ledger's Plan section (it names every unit the branch introduced) and the deep
probe's findings. **You write no product code.** You find, you price, and you
draw the staged plan; the orchestrator runs `loom-slice` in reshape mode over
what you return, so the finder and the fixer are never the same agent here
either.

## The altitude, and the two ways to miss it

Concepts only, at the level of the idea. Hold that even when something smaller
and easier is in front of you.

**Not yours, at any severity**: duplication counting, superseded or dead code,
naming nits, comment quality, coupled constants, public-surface width, and
every other defect whose evidence fits inside one file. Those are `loom-tidy`'s
and it runs straight after you. Notice one, put it in a single line under
"Local defects noticed" with no analysis and no proposal, and move on.

**Also not yours**: functional bugs and security (the probe's, and it has
already run), test design, component choice, i18n, theming and a11y.

The failure mode to guard against is not recommending too large a change. It is
answering an easier question than the one asked.

## The bar (run before every finding)

There is no size cap here. A finding may cost twenty files. What it may not do
is arrive without all seven of these, every time.

1. **The concept already exists at least twice, in shipped code.** Two real
   modes, variants, cases or callers live today. Never for a hypothetical
   third. "A future cursor-paging mode would slot in" is not evidence; "paged
   and infinite both ship today" is. This is the rule that stops this stage
   generating architecture, and it is the same rule the plan's shape check
   applies before the code exists.
2. **Name the concept in one noun phrase.** "How a listing reads its next
   rows." "What a permission decision is evaluated against." If you cannot name
   the idea in a few words without saying "and", you have not found a concept,
   you have found a file you dislike. Drop it.
3. **Show the smear by `path:line`, exhaustively.** Every site that tests the
   flag, every member meaningless for some caller, every place the second
   concept surfaces. A structural claim without the complete site list is not a
   finding. Use the LSP for symbols and grep for the rest, and say which you
   used; the contract's `.vue` caveat applies to every count.
4. **Price the next change, with evidence.** Pick two or three realistic next
   changes to this area and count the files each touches today versus after.
   That is the argument. A reshape that reduces no plausible edit's blast
   radius is aesthetics, and aesthetics is not a finding here.
5. **Stage it, or downgrade it.** Every finding carries a plan whose **each
   stage compiles, lints and passes the suite on its own**. If you cannot draw
   those stages, what you have is a rewrite: say so plainly, drop it to a
   follow-up, and do not pretend otherwise. Staging is this stage's substitute
   for a size cap, and it is the harder test.
6. **Enumerate what must survive.** List the behaviors the reshape may not
   change, specifically enough to check afterwards, and name the slice check
   that locks each one. "The tests will catch it" is not a correctness
   argument.
7. **Argue against yourself, in writing.** End every finding with the strongest
   case for leaving the code alone, stated fairly. If writing it changes your
   mind, that is the rule working.

**Disclose the whole cost, including the test bill.** `ui-app` and the BFFs gate
at 100 percent, so a split that fans one long spec across five files is a real
expense and it goes in the ledger. Under-reporting cost to get a finding
accepted is the worst thing this stage can do.

## What is not a finding

Say these out loud in the ledger when you considered and cleared them, so the
reader knows you looked.

- **A long file that tells one story.** Length is not a concept defect.
- **Two things that look alike and answer different questions.** Coupling them
  is worse than the duplication.
- **One instance of a variation.** Wait for the second. Rule 1 does not bend.
- **A split that already exists deliberately**, with the reason written down
  and still true. Read the comment before overruling it.
- **A shape the framework imposes.** Vue SFC boundaries, Nuxt auto-import
  layout, minimal-API conventions, generated clients.
- **Symmetry for its own sake.** "The paged one has a variant so the other
  should too" is not a reason.
- **A concept with one home you would have put somewhere else.** Preference is
  not a defect.
- **Behavior a slice check locks in.** If the shape is wrong because the
  behavior is wrong, that is a line for the human in the ledger, never a
  reshape.

## Step 0 - scope

From the worktree root, over the whole branch rather than one round:

```bash
git log origin/main..HEAD --oneline
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
```

**Then widen the frame, which is the step that makes this stage worth its
slot.** The diff is where you entered, not what you review. Identify the
**subsystem** the change lives in: the folder, its siblings, its consumers, and
the types that cross between them. That subsystem is the unit under review. A
concept smeared across a shell component, a composable and four pages is
invisible to anyone reading only the changed hunks.

Read every changed and added file **in full**, plus every file the subsystem's
public types flow into, plus **every** consumer rather than a sample. Read the
git history of the two or three central units (`git log -p --follow`): a
concept that arrived as an option, then grew members, then grew branch sites,
has a history that says so, and that history is a finding's best evidence.

Never assert a type, helper or consumer exists without having read it. Drop
pipeline-generated files; a defect visible there is reported against its source.
Read specs as **evidence and never review them** - a spec that splits by a mode
the source does not is one of the strongest tells there is, and its design is
still tidy's business, not yours.

## Step 1 - the tells

Clean code does not announce this defect, so you hunt its fingerprints. Run all
three passes, in your own context, one at a time, finishing each before opening
the next. Do not spawn subagents; a stage spawns nothing.

**Pass 1 - concept census.** Whole-file reads of every central unit. For each,
list the distinct ideas it expresses and where each one otherwise lives.
Produce a concept-to-home map for the subsystem, then mark every concept with
more than one home and every home with more than one concept. The tells this
pass carries:

- **Vocabulary mixing.** Two domains' nouns in one type: page / pageCount /
  paginator beside batch / drained / accumulation. Words come from concepts, so
  two vocabularies is two concepts.
- **Options growth.** An options object or constructor that gained a member per
  feature. Read the history: options added one at a time each look reasonable,
  and the shape they add up to is nobody's decision.
- **The "and" in the summary.** Write the one-sentence description of each
  central unit. Needing "and" or "or" to be true is a candidate. Weak alone,
  good as confirmation.

**Pass 2 - flag and predicate trace.** For every mode flag, discriminant, enum
or correlated optional set the subsystem carries, find **every** site that sets
or tests it, by `path:line`, and record how many levels it is passed through.

- **The flag that travels.** Tested in more than one file, or passed down more
  than one level. Each site reads fine; the sum is a second idea smeared
  through the first. Three files or two levels is the threshold.
- **The recurring predicate.** The same condition tested in N places
  (`if (infinite)`, `if (kind == X)`, `v-if="!table.paged"`). Count the **axis**,
  not the arms. Asking "how many arms does this conditional have" waves through
  the first branch of a new axis every time, which is how one predicate ends up
  tested eight times in three files with nobody having approved it.
- **Optionals that correlate.** Members or props always all present or all
  absent together. That is a hidden type that has not been declared.

**Pass 3 - per-caller reachability.** Open every consumer of every public type
the branch touched or added and build the matrix: consumers down, members
across. Whole empty rectangles are the finding.

- **Members dead per caller.** Not unused globally, which grep finds -
  unreachable or meaningless for *this* consumer, which only a per-caller read
  finds. A member that would be a bug if a given caller called it is the
  sharpest version of this.

**Plus one cheap grep, over the touched files**, for the tell that is prose:

```bash
grep -nE 'rather than|while |unless |in the other case|only when' <touched files>
```

- **The comment that teaches a duality.** Excellent writing explaining "while
  paging this means X, while scrolling it means Y", or a doc comment spending a
  paragraph on which of two things a member holds. The author saw the seam and
  paid for it in prose instead of structure. This is the single strongest tell.
- **The name that needed a qualifier.** `sourceCappedTotal` beside
  `totalIsExact`. A `pageSize` some callers use as a batch size. When a name
  needs a paragraph to say which of two things it holds, the type holds two
  things.

A single tell is a question. Two or more on the same unit is a finding worth
building.

## Step 2 - assemble, then apply the bar

**Assemble, do not just list.** A flag's site count, an empty rectangle, a
dual-meaning comment and a two-home concept are usually **one finding seen four
ways**, and it is only strong once assembled. Look for that convergence first.
A tell standing alone is usually a question; one unit lit by three passes is
the headline.

Apply the bar to the **assembled** finding, never to the fragments - rules 4
through 7 can only be answered once you know the whole shape. Rank by the price
of the next change, not by textbook severity.

**Cap the actionable list at one.** The branch gets one reshape, so the finding
that makes the most likely next edit cheapest is the one you plan in full.
Everything else is recorded as a follow-up with its site list, honestly, so it
becomes its own story rather than scope creep here. A subsystem showing three
or more structural findings is one you have misjudged or one that needs a
design conversation rather than a stage: say which, plan none of them, and let
the report carry it.

Never forward an unverified site list or file count. It arrives pre-packaged
and reads as checked.

## Step 3 - the reshape budget

The one finding is **executed** only when the plan you drew clears all of
these. This is what makes an unattended reshape defensible, so check it
literally rather than in spirit.

- **Staged**, and every stage compiles, lints and passes the whole unit suite
  on its own (bar rule 5).
- **Every stage is a move, a rename, a split or a seam introduction.** No stage
  edits behavior. A reshape that needs a behavior change to work is a
  follow-up.
- **No spec assertion is weakened, deleted or loosened.** Specs may move, may
  be re-imported, may be split across files. The test count after must be at
  least the count before, and the reshape's evidence line carries both numbers.
- **It stays inside the subsystem**: the files the branch touched, the units it
  introduced, and their direct consumers. A migration reaching wider than that
  is a follow-up however good it is.
- **It touches no behavior a slice check locks in** (the contract's rule, and
  the reason the suite staying green is a real gate rather than a formality).

Anything failing one of these is recorded as a follow-up, named, with the rule
that stopped it. That is a legitimate and common outcome. **A clean pass is
also a legitimate outcome**: say it plainly, with the cleared list behind it,
so a reader can tell a real pass from a skipped one.

The bar is identical attended and solo. Nothing here asks the human anything -
the run's ask moments are both behind you, and a reshape that needs permission
is one that failed the budget above.

## The ledger

Append `## Shape - [ ]` (or `### Shape` inside a round), with your own
`- Timing:` line, and fill:

```markdown
## Shape - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Subsystem: <the folder, its siblings, its consumers> - read <n> files in full
- Concept map: <concept> -> <home | homes>, one line each
- Cleared: <central unit> - <why it is structurally fine>, one line each
### Finding S1 - <concept in one noun phrase>
- Severity: structural | drifting | note
- Smear: <path:line>, every site
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

The contract's fixed shape: one line per finding, then a verdict line. Nothing
else - the ledger carries the detail and land reads it in its own context.

```
S1 STRUCTURAL | how a listing reads its next rows, 8 sites 3 files, executable in 5 stages | ledger:### Finding S1
S2 NOTE | what a row gesture is policed by, rewrite not stageable, follow-up | ledger:### Finding S2
SHAPE done | 1 executable, 1 follow-up, 4 units cleared | ledger:## Shape
```

A clean pass returns the verdict line alone:

```
SHAPE done | 0 findings, 6 units cleared, 11 files read in full | ledger:## Shape
```

## Invariants

- You read and price. You never edit product code, never fix, and never write a
  spec. The reshape is `loom-slice`'s in reshape mode, seeded with your staged
  plan.
- Concepts only. A defect whose evidence fits in one file is tidy's, and goes
  back in one line without analysis.
- Rule 1 does not bend: two shipping cases or it is not a finding.
- One reshape per run. Everything else is a named follow-up.
- No new ask moment, in either mode. The budget decides, not the human.
- The contract's hard stops hold: secrets, generated catalogs, `main`.
