---
name: solidify2
description: Structural review of the current branch - the pass that catches locally-clean code carrying two concepts in one unit, and is willing to recommend a large refactor when the evidence supports it. REVIEW AND PLAN ONLY, no edits unless separately asked. Language-agnostic across the momentum monorepo (C# services and ui-app alike). It changes the unit of review from the file to the concept - it asks what distinct ideas the code expresses and whether each has exactly one home - and it prices a refactor rather than rejecting it for being big. Every finding ships with a staged migration plan where each stage compiles and passes, the behaviors that must survive, an honest cost including the test bill, and the strongest argument against doing it. Invoke when the user types /solidify2, or asks "is this the right shape", "should this be split", "would a refactor pay here", "this code is clean but feels wrong", "what would this look like redesigned", or hands over a branch whose code reads well and still feels like it is doing two jobs.
---

# solidify2 Skill

You review the current branch for **structural quality**: whether the concepts the
code expresses each have one home, and whether the shape it landed in is the one a
person would choose knowing everything the branch now knows.

This skill exists because good code hides this class of defect. A unit can be
well-named, carefully commented, fully tested and locally excellent while quietly
carrying two ideas at once. Every local check passes. Nothing is duplicated, nothing
is dead, nothing is misnamed. The cost only appears the next time somebody has to
change one of the two ideas and finds it smeared across eight places.

The bar you are holding is: **can the next person change one of these ideas without
touching the other?** Not "is this file tidy", and not "does this match a pattern".

## The altitude this works at

Structure only, and only at the level of the concept. That focus is the whole design of
the skill, so hold it even when something smaller and easier is in front of you.

**Not this skill's business, at any severity:** duplication counting, dead or superseded
code, naming nits, comment quality, coupled constants, public-surface width, and every
other defect whose evidence fits inside one file. Those are real and they are somebody
else's pass. If you notice one, put it in a single line under "Local defects noticed" at
the end of the report, with no analysis and no proposal, and move on. A report that
drifts into file-level cleanup has stopped doing the one job nothing else does.

The failure mode to guard against is not recommending too large a change. It is
answering an easier question than the one asked.

## Hard boundary

In scope: concept placement, the shape of contracts and types, flags and discriminants
and where they are tested, what each caller can actually reach, vocabulary coherence,
and the cost of the next realistic change.

Out of scope. Note each in one line, name the owner, and do not run that review
here - this skill invokes nothing:

- Functional bugs, correctness, security -> `/code-review`, `/security-review`.
- Performance -> only when the structure forces an algorithmic mistake.
- Nuxt UI component choice, i18n, theming, accessibility -> not this pass.
- **Test design is out of scope, but test code is evidence.** You read specs and you
  never review them. See lens L4.

## The bar (run before every finding)

There is no size cap here. A finding may cost twenty files. What it may not do is
arrive without this. All seven, every time.

1. **The concept must already exist at least twice, in shipped code.** Two real modes,
   variants, cases, or callers live today. Never for a hypothetical third. "A future
   cursor-paging mode would slot in" is not evidence; "paged and infinite both ship
   today" is. This is the rule that keeps the skill from generating architecture.

2. **Name the concept in one noun phrase.** "How a listing reads its next rows."
   "What a permission decision is evaluated against." If you cannot name the idea in a
   few words without saying "and", you have not found a concept, you have found a file
   you dislike. Drop it.

3. **Show the smear, by `path:line`, exhaustively.** Every site that tests the flag,
   every member that is meaningless for some caller, every place the second concept
   surfaces. A structural claim without the complete site list is not a finding. Use
   the LSP for symbols and grep for everything else, and say which you used.

4. **Price the next change, with evidence.** Pick two or three realistic next changes
   to this area and count the files each one touches today versus after. This is lens
   L5's output and it is the argument. A refactor that does not reduce the blast radius
   of any change anyone would plausibly make is aesthetics, and aesthetics is not a
   finding.

5. **Stage it, or downgrade it.** Every finding carries a migration plan where **each
   stage compiles, lints, and passes the suite on its own**. If you cannot draw those
   stages, what you have is a rewrite rather than a refactor: say so plainly, drop it
   to a note, and do not pretend otherwise. Staging is this skill's substitute for a
   size cap, and it is a harder test than size.

6. **Enumerate what must survive.** List the behaviors the refactor may not change,
   specifically enough to check afterwards. A structural change whose correctness
   argument is "the tests will catch it" is not ready to recommend.

7. **Argue against yourself, in writing.** Every finding ends with the strongest case
   for leaving the code alone, stated fairly, not as a strawman. If writing it changes
   your mind, that is the rule working. This replaces the over-engineering veto: the
   defence against a wishlist is an honest counter-argument, not a budget.

**Disclose the whole cost, including the test bill.** Momentum gates components at
100% coverage, so a split that fans one 1200-line spec across five files is a real
expense and it goes in the ledger. Under-reporting cost to get a finding accepted is
the worst thing this skill can do.

## What is not a finding

Say these out loud in the report when you considered and cleared them, so the reader
knows you looked.

- **A long file that tells one story.** Length is not a concept defect. Leave it.
- **Two things that look alike and answer different questions.** Coupling them is worse
  than the duplication.
- **One instance of a variation.** Wait for the second. Rule 1 is not negotiable.
- **A split that already exists deliberately**, with the reason written down and still
  true. Read the comment before overruling it.
- **A shape the framework imposes.** Vue SFC boundaries, Nuxt auto-import layout,
  minimal-API conventions, generated clients.
- **Symmetry for its own sake.** "The paged one has a variant so the other should too"
  is not a reason.
- **A concept with one home that you would have put somewhere else.** Preference is not
  a defect.

## Step 0 - Scope

Run from the worktree root you are standing in.

```bash
git fetch origin main -q
git log origin/main..HEAD --oneline          # the story the commits tell
git diff --stat origin/main                  # size and shape
git diff --name-only origin/main
git ls-files --others --exclude-standard     # new untracked files
```

No diff against `origin/main` and no named target: say so and stop.

If the user named a file, composable, component or subsystem instead, review that in
full. In that mode the target is the anchor and rule 1 reads against the target rather
than the branch.

**Then widen the frame, which is the step that distinguishes this skill.** The diff is
where you entered, not what you review. Identify the **subsystem** the change lives in:
the folder, its siblings, its consumers, and the types that cross between them. That
subsystem is the unit under review. A concept smeared across a shell component, a
composable and four pages is invisible to anyone reading only the changed hunks.

Group by component (`src/<component>/`), read the nearest `CLAUDE.md` and the repo
root's, and drop pipeline-generated files (`fr.json`, `es.json`, `en-XA.json`, XLIFF,
generated clients) - a defect visible there is reported against its source.

Do **not** drop test files here. See L4.

## Step 1 - Ground truth

- Read every changed and added file **in full**, and every file the subsystem's public
  types flow into. A concept claim needs whole files.
- Read **every consumer**, not a sample. Per-caller reachability (L3) is impossible
  from a sample, and it is where the sharpest findings come from.
- For a TypeScript symbol, load the LSP once with `ToolSearch("select:LSP")`, then
  `findReferences` on the export and `goToDefinition` through barrels. Try one `.vue`
  path first: if it answers "No LSP server available for file type", the list is a
  floor, so grep the `.vue` files too. For C#, grep. Cite `path:line` either way.
- Read the **git history of the touched units** (`git log -p --follow` on the two or
  three central files). A concept that arrived as an option, then grew members, then
  grew branch sites, has a history that says so, and that history is the finding's
  best evidence.

Never assert a type, helper or consumer exists without having read it.

## Step 2 - The tells

Clean code does not announce this defect, so you hunt for its fingerprints. These are
the signals that a second concept is living inside a unit that claims one.

1. **The flag that travels.** A boolean, enum or mode passed down more than one level,
   or tested in more than one file. Each site reads fine; the sum is a second idea
   smeared through the first. Count the sites and the levels - three files or two
   levels is the threshold.

2. **The comment that teaches a duality.** The strongest single tell, and the reason
   this skill exists. Excellent prose explaining "while paging this means X, while
   scrolling it means Y", or a doc comment that spends a paragraph disambiguating which
   of two things a member holds. The author saw the seam and paid for it in prose
   instead of structure. Grep the touched files for comments containing "rather than",
   "while", "unless", "in the other case", "only when", near a member declaration.

3. **Members dead per caller.** Not unused globally, which grep finds - unreachable or
   meaningless for *this* consumer, which only a per-caller read finds. Build the
   matrix: consumers down, members across. Whole empty rectangles are the finding.

4. **The name that needed a qualifier.** `sourceCappedTotal` beside `totalIsExact`.
   A `pageSize` that some callers use as a batch size. A `pageState` that means "the
   rows currently listed". When a name needs a paragraph to say which of two things it
   holds, the type is holding two things.

5. **Vocabulary mixing.** Two domains' nouns in one type: page / pageCount / paginator
   beside batch / drained / accumulation. Words come from concepts; two vocabularies is
   two concepts.

6. **The recurring predicate.** The same condition tested in N places (`if (infinite)`,
   `if (kind == X)`, `v-if="!table.paged"`). Count the **axis**, not the arms. A review
   that asks "how many arms does this conditional have" waves through the first branch
   of a new axis every time, which is how one predicate ends up tested eight times in
   three files with nobody having approved it.

7. **Optionals that correlate.** A set of optional members or props that are always all
   present or all absent together. That is a hidden type that has not been declared.

8. **Constructor or options growth.** An options object that gained a member per
   feature. Read the history: options added one at a time each look reasonable, and the
   shape they add up to is nobody's decision.

9. **Tests that split by mode.** A spec with a `describe('while infinite')` block
   re-testing the same surface, or a fixture builder with a mode switch. Test structure
   often reveals the seam the source refused to make. **Read specs as evidence, never
   review them** - do not comment on their design, coverage or duplication, and hand
   anything you notice to the build pass.

10. **The "and" in the summary.** Write the one-sentence description of each central
    unit. If it needs "and" or "or" to be true, that is a candidate. Weak on its own,
    good as a confirmation.

A single tell is a question. Two or more on the same unit is a finding worth building.

## Step 3 - Discover (one subagent per lens)

Discovery is read-only and makes no edits. Launch all five concurrently in one message.
They are cheap relative to a miss.

| Lens | What it owns | How it looks |
| --- | --- | --- |
| **L1. Concept census** | Tells 5, 8, 10 | Whole-file reads of every central unit. For each, list the distinct concepts it expresses and where each one otherwise lives. Produce a concept-to-home map for the subsystem and mark every concept with more than one home, and every home with more than one concept. |
| **L2. Flag and predicate trace** | Tells 1, 6, 7 | For every mode flag, discriminant, enum or correlated optional set the subsystem carries, find **every** site that sets or tests it, by `path:line`, and record how many levels it is passed through. |
| **L3. Per-caller reachability** | Tell 3 | Open every consumer of every public type the change touched. Build the consumer-by-member matrix. Report the empty rectangles: members a given caller can never use, and members that would be a bug if it did. |
| **L4. Vocabulary, comments and test shape** | Tells 2, 4, 9 | Read the prose. Comments that teach a duality, names that needed a qualifier, doc comments that disambiguate two meanings, spec files whose structure splits by a mode the source does not. Quote them. |
| **L5. Change-cost probe** | Rule 4 | Pick two or three realistic next changes to this subsystem, grounded in the repo (a real backlog item, an obvious next variant, a behavior change to one concept). For each, list the files a person must touch **today**, by name. This is the evidence any large finding stands on, so it is done by reading, not by estimating. |

Seed every lens with: read `~/.claude/skills/solidify2/SKILL.md` first (the bar and the
tells are binding and must not be paraphrased from memory); the Step 0 scope and the
subsystem boundary; its own row above, verbatim; the LSP note from Step 1; and this
boundary - *everything outside your lens belongs to another reviewer running right now,
so do not report it and do not go looking for it.*

Each lens returns three lists: **findings** (in the field shape below), **searched**
(files read in full, greps and `findReferences` run and what they returned, claims it
could not verify), and **cleared** (candidates it examined and dropped, one line each
with which rule or which "not a finding" case killed it).

If the Agent tool is unavailable (this skill nested inside another), run the five
lenses **sequentially in your own context**, finishing one lens's searches and lists
before opening the next, and say so in the report.

## Step 3b - Merge

The lenses find; you decide.

1. **Assemble, do not just dedupe.** This is the difference from a defect review. L2's
   flag sites, L3's empty rectangle, L4's dual-meaning comment and L1's two-home
   concept are usually **one finding seen four ways**, and it is only a strong finding
   once assembled. Look for that convergence before you look for duplicates. A tell
   reported alone by one lens is usually a question; the same unit lit up by three
   lenses is the report's headline.
2. **Apply the bar to the assembled finding**, not to the fragments. Rules 4, 5, 6 and
   7 can only be answered once you know the whole shape.
3. **Rank by the price of the next change**, from L5, not by textbook severity. The
   finding that makes the most likely next edit cheapest goes first.
4. **Cap the report at three structural findings.** A subsystem with four is a
   subsystem you have misjudged, or one that needs a design conversation rather than a
   review. Say which.
5. **Never forward an unverified site list or file count.** It arrives pre-packaged and
   reads as checked. Send it back or drop it.

## Step 4 - The report

Markdown in the chat. No file is written unless the user asks.

Open with two or three sentences: what the branch did structurally, and whether the
shape it landed in is the one to keep. Then the findings, ranked.

Each finding carries:

- **`concept`** - the idea, in one noun phrase (bar rule 2).
- **`severity`** - **structural** (the concept is smeared and the next change to it
  will be made in several places), **drifting** (one home today, but the branch put the
  second tenant in and a third would go there too), **note** (real, but the fix is a
  rewrite you could not stage - rule 5).
- **`where it lives now`** - every site, `path:line`, complete (rule 3).
- **`the tells`** - which of Step 2 fired, with the quoted comment or the empty
  rectangle or the site count as evidence.
- **`price of the next change`** - from L5. Files touched today by change X, by name;
  files touched after. This is the argument.
- **`target shape`** - the concrete end state. Type signatures, file names, component
  boundaries. Specific enough to build from.
- **`staged plan`** - numbered stages, each one compiling and passing on its own, with
  what lands in each (rule 5).
- **`must survive`** - the behaviors the refactor may not change (rule 6).
- **`cost`** - files added, files touched, spec files split, net line direction, and an
  honest word on the test bill.
- **`the case against`** - the strongest argument for leaving it alone (rule 7).

Then, in short lists:

- **Structurally fine** - the central units you examined and cleared, one line each
  with why. An empty findings list with a real cleared list is a good result.
- **Local defects noticed** - file-level things outside this skill's altitude, one
  line each, no analysis and no proposal.
- **Out of scope** - correctness, security, tests, a11y, pointing at the owning skill.
- **Subsystem checked** - the merged searched lists, including lenses that came back
  empty, so the reader knows the coverage.

Offer at the end to write the top finding up as a spec from `docs/spec-template.md`,
or to implement stage 1. Do neither unless asked.

## Calibration: a worked catch

The `inboxInfiniteScroll` branch in momentum is the reference case for what this skill
is for: a change whose every file reads well and whose shape is still wrong.

- **What it did.** Added infinite scrolling to a listing subsystem behind one option,
  `useDataTable({ infinite: true })`.
- **Why it looks clean.** Every member is documented, the comments are unusually good,
  the behavior is right, coverage is 100%.
- **The tells that fire.** *Flag that travels* (`infinite` tested in `useDataTable`,
  in the listing shell, and passed as a prop into a leaf checkbox: three files, three
  levels). *Comment teaching a duality* (members whose doc comments spend a paragraph
  on what they mean while paging versus while scrolling). *Members dead per caller*
  (three paged pages can never call `loadMore`, `hasMore`, `batchCount`,
  `totalIsExact`; the scrolling page can never call `setPage`, `pageCount`,
  `setPageSize`). *Vocabulary mixing* (`page`/`pageCount`/`paginator` beside
  `batch`/`drained`/`accumulation` in one type). *Recurring predicate* (eight sites on
  one axis, none of which looks like a decision on its own).
- **The concept.** "How a listing reads its next rows." It has two homes and one type.
- **What a file-level read gets.** The leaf's `infinite?: boolean` prop, and maybe the
  widened state interface: the two sites where the defect is visible from inside one
  file. Not the shape.
- **What this skill adds.** The assembled finding across all four tells, the per-caller
  matrix as its evidence, and a staged plan that lands the split in five green stages.

Use it to calibrate severity: that is a **structural** finding, not a note, because the
next person adding a reading mode or changing one edits eight sites across three files.
