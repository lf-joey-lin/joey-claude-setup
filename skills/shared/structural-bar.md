# The structural bar (shared)

The doctrine for finding a **structural** defect: one concept living in more than one
home. Read by `solidify` (as its High half) and by `loom-shape` (as its whole job).
Each of those skills carries its own scope, output format and budget; this file
carries the part that must not differ between them.

## The defect

A unit can be well named, carefully commented, fully covered, probed and locally
excellent while quietly carrying two ideas at once. Every local check passes. Nothing
is duplicated, nothing is dead, nothing is misnamed. The cost arrives the next time
somebody has to change one of the two ideas and finds it smeared across eight places.

The bar you hold is: **can the next person change one of these ideas without touching
the other?** Not "is this file tidy", and not "does this match a pattern".

## The altitude, and the two ways to miss it

Concepts only, at the level of the idea.

**Never a structural finding:** duplication counting, dead or superseded code, naming
nits, comment quality, coupled constants, public-surface width, and every other defect
whose evidence fits inside one file. Those are real and they belong to the reader's
other half (`solidify`'s maintainability list, or `loom-tidy`). Notice one, write it
down in one line with no analysis, and move on.

**Also never yours:** functional bugs, correctness and security, test design, component
choice, i18n, theming, a11y.

The failure mode to guard against is not recommending too large a change. It is
answering an easier question than the one asked.

## Discovery: pair up, then diff the pair

This is the part that makes the pass cheap, and it is derived from what real findings
turned out to need rather than from what a thorough review sounds like.

**The evidence.** Across two full runs on momentum (`bpDelete`, three findings;
`bplisting2`, five), **every one of the eight was a two-home pair**, and every sibling
was reachable by one of three mechanical searches. None of them needed a whole-subsystem
read. `bpDelete`'s three findings cite 11 files and 3,177 lines between them; the run
that produced them built a frame of 181 paths and read it several times over.

So the unit of discovery is **a pair**, not a subsystem. Pairs are bounded, the diff
between the two sides *is* the evidence, and the site list falls out of that diff
instead of an exhaustive sweep.

### The three searches

For each unit the change introduced or substantially rewrote, look for its nearest
sibling three ways. These are greps and directory listings, not reads.

1. **Same folder.** Another file beside it doing the same kind of job, and any existing
   shared helper in that folder. (Found `bpDelete` H2: two contract records with the
   same `TryCreate` routine, plus `ListingPaging.cs`, the house precedent for exactly
   that extraction, sitting in the same directory with three callers.)
2. **Other consumers of something shared it imports.** Take the shared components,
   types and composables the unit reaches for, and find who else reaches for them.
   (Found `bpDelete` H1 and H3: the new composable and a shipped one in a different
   feature area both consume `ActionDialog.vue`.)
3. **Vocabulary.** The unit's two or three most distinctive nouns, grepped app-wide.
   This is the one that catches a sibling sharing no import. (Found `bplisting2`'s
   bulk-action-run and session-expiry concepts.)

Also worth one look: a **parallel name in a sibling folder**
(`bp/deleted.vue` beside `workflows/deleted.vue`) is search 1 one level up, and it
found `bplisting2`'s retention-copy concept.

Write the pair table before reading anything. Discovery ends there.

### Diffing a pair

Read both sides in full, then build the **part-by-part table**: one row per part of the
concept, the two sides' `path:line` in the two columns. That table is not the write-up
of the finding, it is the finding.

- A pair whose parts line up row for row is a candidate. Take it to the bar.
- A pair that diverges after two rows is cleared. One line saying so, and move on.
- Where provenance matters, one `git log -1 --format` on the sibling file. Never
  `git log -p`.

### The frame, as a hard rule

Read in full: the units the change introduced or rewrote, plus each pair's sibling.
Everything else is grep with `path:line` cites. A pass that starts reading a subsystem
has stopped doing this and has gone back to costing six times as much.

### The one escalation

The per-caller matrix (tell 3) is the expensive device and it is worth paying for
**on demand, never upfront**. When a mode flag or discriminant sits on a public type
with more than about three consumers, then open every consumer of *that one type* and
build the matrix: consumers down, members across, empty rectangles are the finding.
Not for anything else.

**What this frame gives up, and say so in the report:** a concept smeared across a
subsystem with no sibling pair and no shared declaration, and a pre-existing smear
between two units the change never touched. Vocabulary search is the only thing
reaching those and it is a floor, not a proof.

## The tells

Clean code does not announce this defect, so you hunt its fingerprints. A single tell
is a question. Two or more on the same unit is a finding worth building.

| # | Tell | Where it surfaces |
| --- | --- | --- |
| 1 | **The flag that travels.** A boolean, enum or mode tested in more than one file, or passed down more than one level. Each site reads fine; the sum is a second idea smeared through the first. Three files or two levels is the threshold. | axis check |
| 2 | **The comment that teaches a duality.** Excellent prose explaining "while paging this means X, while scrolling it means Y", or a doc comment spending a paragraph on which of two things a member holds. The author saw the seam and paid for it in prose instead of structure. The single strongest tell. | pair diff, plus `grep -nE 'rather than\|while \|unless \|in the other case\|only when'` over the changed files |
| 3 | **Members dead per caller.** Not unused globally, which grep finds - unreachable or meaningless for *this* consumer. A member that would be a bug if a given caller called it is the sharpest version. | declarations, then the escalation |
| 4 | **The name that needed a qualifier.** `sourceCappedTotal` beside `totalIsExact`. A `pageSize` some callers use as a batch size. When a name needs a paragraph to say which of two things it holds, the type holds two things. | pair diff |
| 5 | **Vocabulary mixing.** Two domains' nouns in one type: page / pageCount / paginator beside batch / drained / accumulation. Words come from concepts, so two vocabularies is two concepts. | pair diff |
| 6 | **The recurring predicate.** The same condition tested in N places (`if (infinite)`, `if (kind == X)`, `v-if="!table.paged"`). Count the **axis**, not the arms. Asking "how many arms does this conditional have" waves through the first branch of a new axis every time, which is how one predicate ends up tested eight times in three files with nobody having approved it. | axis check |
| 7 | **Optionals that correlate.** Members or props always all present or all absent together. That is a hidden type that has not been declared. | axis check |
| 8 | **Options growth.** An options object or constructor that gained a member per feature. Options added one at a time each look reasonable, and the shape they add up to is nobody's decision. | pair diff |
| 9 | **Tests that split by mode.** A spec with a `describe('while infinite')` block re-testing the same surface, or two spec files testing one lifecycle under different names. Test structure often reveals the seam the source refused to make. Read specs as **evidence and never review them**; a `grep -n "describe(\|it("` index is usually enough. | pair diff |
| 10 | **The "and" in the summary.** Write the one-sentence description of each central unit. Needing "and" or "or" to be true is a candidate. Weak alone, good as confirmation. | pair diff |

## The bar (run before every finding)

There is no size cap. A finding may cost twenty files. What it may not do is arrive
without all seven of these, every time.

1. **The concept already exists at least twice, in shipped code.** Two real modes,
   variants, cases or callers live today. Never for a hypothetical third. "A future
   cursor-paging mode would slot in" is not evidence; "paged and infinite both ship
   today" is. This is the rule that stops the pass generating architecture.
2. **Name the concept in one noun phrase.** "How a listing reads its next rows." "What
   a permission decision is evaluated against." If you cannot name the idea in a few
   words without saying "and", you have not found a concept, you have found a file you
   dislike. Drop it.
3. **Show the smear by `path:line`, exhaustively.** Every site that tests the flag,
   every member meaningless for some caller, every place the second concept surfaces.
   A structural claim without the complete site list is not a finding. Say whether the
   list came from the LSP or from grep, and where the frame is the limit, say that too.
4. **Price the next change, with evidence.** Pick a realistic next change to this area
   and count the files it touches today versus after, by name. The pair table is where
   that count comes from, so this is arithmetic rather than a separate investigation.
   A reshape that reduces no plausible edit's blast radius is aesthetics, and
   aesthetics is not a finding.
5. **Stage it, or downgrade it.** Every finding carries a plan whose **each stage
   compiles, lints and passes the suite on its own**. If you cannot draw those stages,
   what you have is a rewrite rather than a refactor: say so plainly, drop it to a
   follow-up, and do not pretend otherwise. Staging is the substitute for a size cap,
   and it is the harder test.
6. **Enumerate what must survive.** List the behaviors the refactor may not change,
   specifically enough to check afterwards. "The tests will catch it" is not a
   correctness argument.
7. **Argue against yourself, in writing.** End every finding with the strongest case
   for leaving the code alone, stated fairly, not as a strawman. If writing it changes
   your mind, that is the rule working.

**Disclose the whole cost, including the test bill.** `ui-app` and the BFFs gate at 100
percent, so a split that fans one long spec across five files is a real expense and it
goes in the ledger. Under-reporting cost to get a finding accepted is the worst thing
this pass can do.

## What is not a finding

Say these out loud when you considered and cleared them, so the reader knows you looked.

- **A long file that tells one story.** Length is not a concept defect.
- **Two things that look alike and answer different questions.** Coupling them is worse
  than the duplication.
- **One instance of a variation.** Wait for the second. Rule 1 does not bend.
- **A split that already exists deliberately**, with the reason written down and still
  true. Read the comment before overruling it.
- **A shape the framework imposes.** Vue SFC boundaries, Nuxt auto-import layout,
  minimal-API conventions, generated clients.
- **Symmetry for its own sake.** "The paged one has a variant so the other should too"
  is not a reason.
- **A concept with one home you would have put somewhere else.** Preference is not a
  defect.

## Assemble, do not list

A flag's site count, an empty rectangle, a dual-meaning comment and a two-home concept
are usually **one finding seen four ways**, and it is only strong once assembled. Look
for that convergence before you look for duplicates. A tell standing alone is usually a
question; one unit lit by three tells is the headline.

Apply the bar to the **assembled** finding, never to the fragments - rules 4 through 7
can only be answered once you know the whole shape. Rank by the price of the next
change, not by textbook severity.

**Never forward an unverified site list or file count.** It arrives pre-packaged and
reads as checked.

## Calibration: two worked catches

**The pair.** `bpDelete` added `useBusinessProcessBulkActions.ts`. Locally excellent,
fully covered. Search 2 found `useUserBulkActions.ts` in a different feature area
through their shared `ActionDialog.vue`. The pair diff produced a 14-row part-by-part
table where every part of "the lifecycle of a confirmed bulk action over a listing
selection" appeared on both sides, down to a `copy()` i18n helper and a
run-generation counter implemented twice independently (10 sites against 8). Tells 1, 2,
6 and 9 all fired on the same unit. The doc comment on one was the other's with the
nouns swapped. **Structural**, and the write-up is mostly the table.

**The flag.** `inboxInfiniteScroll` added infinite scrolling to a listing behind one
option, `useDataTable({ infinite: true })`. Every member documented, comments unusually
good, behavior right, coverage 100 percent. The axis check finds `infinite` tested in
the composable, in the listing shell and passed as a prop into a leaf checkbox: three
files, three levels, eight sites on one axis, none of which looks like a decision on
its own. The concept is "how a listing reads its next rows" and it has two homes and
one type. The escalation earns its keep here: the matrix shows three paged pages that
can never call `loadMore`/`hasMore`/`batchCount`/`totalIsExact` and one scrolling page
that can never call `setPage`/`pageCount`/`setPageSize`. Contrast the leaf's
`infinite?: boolean` prop taken alone - one prop in one file, no second home to point
at - which is a one-line local note.
