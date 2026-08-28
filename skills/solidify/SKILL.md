---
name: solidify
description: Review the current branch's work for SOLID, DRY, and code maintainability quality only, and report the findings as one flat list ranked most to least important. REVIEW ONLY, no edits unless separately asked. Language-agnostic across the momentum monorepo (C# services and ui-app alike). Judges the branch in the context of the whole app rather than the diff alone, so it also catches superseded code the change left behind and existing code that should converge on a shared unit the branch introduced. Every finding must first survive a strict over-engineering veto, so what comes back is a short list of real maintainability defects, not textbook advice. Functional bugs, security, tests, performance, and accessibility are out of scope and get handed to the skills that own them. Invoke when the user types /solidify, or asks to "check this for SOLID", "review for DRY", "am I duplicating anything", "is this maintainable", "code quality pass on my branch", or hands over a branch and asks whether the design holds up.
---

# solidify Skill

You review the work on the current branch for **design and maintainability
quality**: SOLID, DRY, and the ordinary things that make code expensive to change
later. You report findings as one flat list, ranked most important first, so the
reader can stop partway down and know the worst is behind them.

The bar you are holding is "will the next person changing this code be misled, or
have to make the same edit in three places" - not "does this match a textbook
pattern". Most reviews of this kind fail by recommending architecture nobody asked
for. The veto below exists to stop that.

You judge the branch **in the context of the whole app, not the diff alone**. A diff
only shows what was added; the maintainability cost usually lives in what the addition
did to everything around it. Two classes of defect are invisible from the diff and are
squarely yours:

- **What the change superseded and left behind.** A new file, component, endpoint,
  composable or migration that replaces an old one is only half a change until the old
  one is deleted. Two ways to do the same thing is the expensive outcome, and the
  second person cannot tell which is current.
- **What should now converge on the new shape.** When the branch builds a better unit
  (a shared UI component, a helper, a base type), the pre-existing hand-rolled copies
  of that same thing are now duplication the branch created the resolution for. That
  is worth a finding even though those files are not in the diff.

Both still go through the veto. The point is that reading wider finds real defects,
not that a wider scope licenses a bigger wishlist.

## Hard boundary: maintainability only

In scope: the dimensions in Step 2 - single responsibility, open/closed,
substitutability, interface segregation, dependency inversion, DRY / duplication,
naming and readability, dead code, public surface width, coupled constants,
shared-unit blast radius, superseded code left behind, and convergence on a unit the
branch introduced.

Out of scope, hand each to its owner and do not fold it in here:

- **Functional bugs, correctness, silent failures, security** -> `/code-review`,
  `/security-review`.
- **Tests and coverage** -> the `update-tests` skill. Test code is not reviewed
  here at all - not its design, not its duplication. You may note that a design
  makes something untestable when that is the maintainability defect, but you do
  not write, judge, or review tests.
- **Performance** unless the change makes an algorithmic mistake that is also a
  design mistake. A micro-optimization is not a solidify finding.
- **Nuxt UI component choice, i18n, theming tokens, accessibility** in `ui-app`
  -> `review-ui` and `implement-ui` own those. Do not re-litigate them.

If you spot one of these while reviewing, do not fix it. Collect it under "Out of
scope but worth noting" at the end of the report, pointing at the owning skill.

## The over-engineering veto (run before every finding)

A finding is only reported if it passes **all** of these. This is the point of the
skill; be strict and drop things.

1. **One call site raises the bar; it does not close the door.** The default is still
   to wait for the second real use, and for polymorphism machinery it is a flat no:
   no interface, base class, generic type parameter, factory, strategy, registry or
   plugin seam for a variation that does not exist yet. "It might be reused" is not a
   use.

   A plain extraction is different. A helper, composable, module or child component
   called from one place is worth recommending when it earns its keep on either count:

   - **The host file gets better.** Pulling a self-contained chunk out leaves the
     caller shorter and easier to follow, and the chunk is coherent enough to name in
     a few words. Say roughly how many lines leave the caller and what the new unit is
     called. Length alone is not the argument - a long file that tells one story stays
     as it is (dimension 1 still holds).
   - **The unit is generic, so a second use is likely.** Judge that on the code, not on
     optimism. It takes everything it needs as arguments, knows nothing about the
     caller's screen or feature, carries no caller-specific flags, and its name would
     still be right somewhere else in the app. Name the plausible next caller or the
     class of caller. A unit that only makes sense where it already sits fails this,
     and so does one that would need a flag per caller.

   Existing code elsewhere in the app that already does the same thing by hand **does**
   count as a real use - cite it by `path:line`. One call site in the diff plus three
   hand-rolled copies in the app is four uses, not one.

   A single-use extraction reported on these grounds is **recommended** at best, more
   often **minor**, never must-fix, and it still has to clear rule 4.

2. **One implementation means no interface.** Extracting a contract for a type with
   one implementation only earns its keep when there is a real seam behind it (a
   boundary the code already crosses - clock, filesystem, HTTP, DB - or an existing
   DI registration the surrounding component already uses). Say which seam.
3. **Two is a note, three is a finding.** Rule of three for duplication. Two copies
   are reported only when they share an invariant that will silently drift (they must
   agree for the code to be correct), and then the fix is to name the value once, not
   to build a framework.
4. **The fix must pay for what it adds.** State the cost of every proposal in
   concrete terms: files touched, indirection added, net lines. Net lines is not the
   only ledger - an extraction that adds a file but leaves the caller materially
   easier to read pays for itself, as long as the reader follows one hop and not
   three. What does not pay is more files, more hops, and a caller that reads exactly
   the same as before.
5. **No pattern names as justification.** If you cannot argue the fix in plain terms
   by what it removes or what future edit it de-risks, it is not a finding. "Use a
   strategy pattern here" on its own is not an argument.
6. **The repo's existing pattern wins.** Match how the surrounding component already
   does this (nearest `CLAUDE.md`, sibling files) over generic best practice. A
   finding that asks the branch to be the one file in the component doing it
   differently is a wrong finding.
7. **Anchored to the branch's work, not confined to the diff.** Every finding must
   trace back to something the change did. You read the whole app to judge that, and a
   finding may name files outside the diff, but you need one sentence saying what the
   branch did to make it a finding now. Three legitimate shapes:
   - the change **superseded** it (the old file, component, endpoint, route, key or
     flag has no reason to exist now),
   - the change **built the resolution** for it (the branch introduced the unit those
     pre-existing copies should use),
   - the change **made it materially worse** (added the third copy, widened the
     interface, built on the wrong seam).

   Say which one, and say plainly when the root of it predates the branch. A wart that
   fits none of the three is not this review's business, however tempting - it is a
   backlog item, and belongs at most in one line at the end.
8. **Convergence must be worth the migration.** A "refactor the old components onto
   the new one" finding costs edits in files the branch never opened, so it carries a
   higher bar: at least two pre-existing sites, behavior that is genuinely the same
   rather than merely similar-looking, and each site named with what changes there. If
   the sites differ enough that the shared unit would need a flag or a variant per
   caller to absorb them, the honest finding is "these are not the same thing" and you
   drop it. Where the migration is real but larger than the branch, say so and
   recommend it as follow-up work rather than pretending it is a small diff.

When something fails the veto but you still think it is worth one line, put it in a
short "Deliberately not flagged" list at the end of the report with the reason. That
is how the reader knows you looked and decided, rather than missed it.

## Step 0 - Establish the scope

Review the current branch against the latest `origin/main`, including committed,
staged, unstaged, and new files. Run from the worktree root (`C:\code2\momentum` on
Windows, `~/m-code/momentum` on WSL, or the feature worktree you are standing in):

```bash
git fetch origin main -q
git diff --name-only origin/main          # tracked changes: committed + staged + unstaged
git diff --stat origin/main               # size of the change
git ls-files --others --exclude-standard  # new untracked files
```

Sanity-check the file list looks like the work the user described.

If there is no diff against `origin/main`, say so and stop - there is nothing to
review. If the user named a specific file, class, or component instead, review that
target in full and the no-diff stop does not apply. In that mode the target itself is
the anchor: veto rule 7's tracing requirement is waived, and where a dimension says
"the branch", read "the target".

Then group the changed files by component (`src/<component>/`,
`infrastructure/<x>/`) - the review runs per component, because that is the unit that
carries its own conventions. Two kinds of file are dropped from the review set here:

- **Test files.** Tests belong to `update-tests` and are not reviewed by this skill.
- **Pipeline-generated files**: `fr.json`, `es.json`, `en-XA.json`, the XLIFF memory,
  generated API clients, and anything else a pipeline regenerates. A defect visible
  in generated output is reported against its source (`en.json`, `openapi.yaml`),
  never against the generated file.

The diff is the anchor, not the boundary. Before Step 1, get the shape of the change so
you know how wide to read:

```bash
git diff --diff-filter=A --name-only origin/main   # added files: what might supersede something
git diff --diff-filter=D --name-only origin/main   # deleted files: what was already cleaned up
git diff --diff-filter=M --stat origin/main        # modified files: where the change landed
git log origin/main..HEAD --oneline                # the story the commits tell
```

Ask the user what the change is meant to replace when it is not obvious, and take their
answer as the map. When there is no human to ask (a headless or pipeline run), infer it
from the commit messages and file names and state the assumption in the report. An
added file with a name close to an existing one, a new component
that renders what an existing page renders inline, a new endpoint next to an old route,
a v2 of anything: each is a signal that Step 1 needs to go looking outside the diff.
Note them now as questions to answer, not as findings.

## Step 1 - Ground truth before judging

Duplication and responsibility claims cannot be made from a diff. Before writing any
finding:

- Read each changed or added file **in full**, not just the changed hunks. A
  single-responsibility or public-surface claim needs the whole file.
- Read the **neighbours**: the sibling files in the same folder, the callers of what
  changed, and the interface or base type it implements. This is what separates real
  duplication from two things that merely look alike, and it is where the veto's
  rules 1, 2, and 6 get their evidence.
- Read the **nearest `CLAUDE.md`** (the component's, then the repo root's) for the
  conventions that component holds itself to. The root file's code style is binding:
  C# `net10.0`, nullable enabled, no `var`, `Laserfiche.*` namespaces, minimal public
  surface with `internal` plus `InternalsVisibleTo` rather than widening access,
  SOLID for new code, no em dash / emoji / arrows / box-drawing characters.
- For a duplication claim, **grep for the other copies** and cite each one by
  `path:line`. A DRY finding without the other locations named is not a finding.

Never assert that an API, type, or helper exists without having read it. A wrong
"there is already a helper for this" is worse than saying nothing.

### The app-context pass

Run this for every added file and every new exported unit (component, composable,
helper, endpoint, type, constant). It is the part a diff-only review skips.

- **Does something already do this?** Search by name, by the distinctive strings and
  props it carries, and by the shape of the markup or logic - not just the filename.
  Names diverge; behavior does not. Look in the component's own folder, the shared /
  common folder, and the app's existing pages. In `ui-app`, an obvious tell is the same
  markup or the same state machine written inline in two pages.
- **What did it replace, and is the old one still there?** For each added unit, find the
  old one and check whether anything still reaches it. Follow every thread it was wired
  into, because deletion is rarely one file:
  - imports, barrel exports, `index` re-exports, auto-import globs
  - routes, pages, nav entries, DI registrations, service collection wiring
  - `en.json` keys, `data-testid` references, storybook stories, tests
  - config, feature flags, openapi entries, generated clients
  A superseded file with zero remaining references is a deletion finding. One that still
  has live references is not dead yet, and the finding is that the branch left two live
  paths to the same behavior, which is a different and often worse problem. Say which
  case it is.
- **Who else should be using the new thing?** For each genuinely reusable unit the
  branch added, grep the app for the code it makes redundant, open each hit, and decide
  whether it is the same behavior or only the same silhouette. Count the sites. That
  count, plus how generic the unit is, is what veto rules 1 and 8 are decided on.
- **Did the branch add its own second way of doing something?** The reverse case: an
  added file that hand-rolls what a shared unit already provides. The fix is to adopt
  the existing one and delete the new code, which is the cheapest finding in the whole
  report - prefer it over any new abstraction.

Do not guess at reference counts. Every "nothing uses this any more" and every "these
four places do the same thing" claim needs the search behind it, and the report cites
the locations.

## Step 2 - The dimensions

Run each dimension against the changed code. Each one says what to flag and, just as
importantly, what not to.

1. **Single responsibility.** Flag a class, component, composable, or function that
   has two genuinely separate reasons to change, where the split is **already visible
   in the code** - two disjoint clusters of fields or state, a method that both
   decides and performs, a component that both fetches and renders in a codebase
   whose siblings separate the two. Do not flag a file for being long, and do not
   propose a split you cannot draw the seam of in one sentence. Lifting one
   self-contained chunk out of a file to make it read better is not this dimension; it
   is the extraction case in veto rule 1, and it is reported at that lower severity.

2. **Open/closed.** Flag when the change added the **second or third** branch to an
   existing conditional on the same axis (a `switch` on type, an `if` chain on kind,
   a lookup that now needs a new arm each time) and the arms are visibly parallel. Do
   not flag the first branch, and do not ask for an extension point for a variation
   that does not exist yet (veto rule 1).

3. **Substitutability (LSP).** Flag an implementation or subclass that lies about its
   contract: throwing `NotSupportedException`, silently no-oping a member, narrowing
   what a base accepts, or strengthening what callers must do. This is a must-fix
   class of finding when a caller can reach it through the base type - the next
   person will hit it.

4. **Interface segregation.** Flag an interface or props contract whose members the
   new consumer does not use while another consumer only wants a subset, or one that
   forces an implementation to stub members it has no meaning for. Do not split an
   interface whose only implementation and only consumer both use all of it.

5. **Dependency inversion.** Flag new code that constructs a concrete dependency
   inline (an HTTP client, DB context, `DateTime.Now`, filesystem, config read) when
   the surrounding component already takes its dependencies through DI or its
   constructor - it is now a hidden dependency and an untestable seam. Do not demand
   an interface for a plain data type or a helper with no seam (veto rule 2).

6. **DRY / duplication.** Flag logic (not shape) repeated in three or more places, or
   twice where the copies must agree to be correct. Count the copies **across the app**,
   not just inside the diff: the branch adding the third copy of something that already
   existed twice is the same finding as three copies inside one new file, and it is the
   more common one. Same-looking code that answers different questions is not
   duplication, and coupling it is the worse outcome - say so when you decide that. Name
   every location. The proposal should be the smallest thing that removes the drift: one
   named constant, one call, one existing helper already in the repo. Prefer moving a
   duplicate to the helper that already exists over inventing a new one, and prefer
   deleting the branch's new copy over generalizing it.

7. **Coupled constants and implicit invariants.** A literal whose correctness depends
   on matching a value somewhere else is a defect even when nothing looks duplicated
   - a size that must equal a sibling's padding, a timeout that must be under a
   caller's, a string key spelled in two files, a limit that must match a DB column.
   Trace each new constant to what it is implicitly coupled to and confirm they
   agree; the fix is one source of truth (derive it, or name it once).

8. **Naming, readability, dead code.** Flag names that mislead (a `Get` that mutates,
   a plural holding one thing, a bool named for the negative), dead or commented-out
   code, unused parameters/props/returns, deep nesting where an early return is the
   idiom in that file, and boolean flag parameters that select between two behaviors.
   Dead code inside the diff belongs here; a whole unit the change orphaned elsewhere in
   the app belongs to dimension 11.
   Flag comments that narrate what the code says; the repo wants comments only for a
   non-obvious "why".

9. **Public surface width.** Flag a member, prop, export, or return value made public
   that no consumer reads, and access widened past what tests need. The repo's rule is
   `internal` plus `InternalsVisibleTo` over `public` in C#, and props down / events
   up with the narrowest contract in `ui-app`.

10. **Shared-unit blast radius.** When the change touches something shared - a common
    component, a composable, a state or cookie key, an extension method, a base class
    - the design must hold for **every** consumer, not the one in front of you. Grep
    the call sites and open each. A change correct at the definition and for one
    caller is often silently wrong for a sibling that never appears in the diff. This
    is also where an unused prop or return value becomes visible.

11. **Superseded code left behind.** Flag the old thing the change replaced but did not
    remove: the previous component, file, endpoint, route, composable, DTO, constant,
    feature flag, `en.json` key, story or test that now has no live reference. Two ways
    to do the same job is the real cost - the next person picks one at random, or
    changes the dead one and wonders why nothing happened. Name every leftover
    reference thread you found (barrel export, route table, DI registration, translation
    key) so the deletion is a checklist, not a guess. Do not flag something as dead
    without the search behind it, and do not flag a deliberate deprecation path (a
    published contract, an in-flight migration, anything marked obsolete on purpose) -
    that is a choice, and if it is undocumented the finding is the missing note, not the
    deletion. When the old path is still live, the finding is the duplicate path itself
    and the proposal is to pick one.

12. **Convergence on the branch's own unit.** Flag pre-existing code that should now be
    refactored onto something the branch introduced: the new shared component that two
    pages already hand-roll, the new helper that replaces three inline copies, the base
    type the existing siblings should sit under. The branch did the hard part by
    building the unit; leaving the old copies means the app now has the abstraction and
    the duplication at once, and the next edit to that behavior still has to be made in
    four places. Bar for reporting is veto rule 8: two or more pre-existing sites, real
    behavioral sameness, each site named with what changes there and whether the shared
    unit needs to grow to absorb it. If absorbing them all needs a flag or a variant per
    caller, say they are not the same thing and drop it. Size the migration honestly and
    call it follow-up work when it is bigger than the branch.

## Step 3 - Discover the findings

Discovery is **read-only**. It makes no edits, in any mode.

- **A small change** (one component, a handful of files) - review it inline. Do not
  spin up machinery for a 200-line diff.
- **A change spanning several components** - dispatch one `general-purpose` subagent
  per component, run concurrently, each seeded with that component's changed files,
  its `CLAUDE.md` path, and the instruction to first read this skill file at
  `~/.claude/skills/solidify/SKILL.md` (the veto and the dimensions) - the subagent
  does not have it loaded, and a paraphrased veto is a weakened one. Keep the diff
  reading out of your own context and let each report back.

Whichever route you take, the app-context pass from Step 1 has to actually run. When
the change adds files or a new reusable unit, give it its own concurrent
`general-purpose` subagent so it is not squeezed in at the end of a per-component
review: seed it with the list of added files and new exported units, the instruction to
first read this skill file (dimensions 6, 11 and 12 and veto rules 1, 7 and 8 are its
brief), and the instruction to search the whole app for prior art, orphaned
predecessors, and hand-rolled copies, reporting each hit as `path:line` with the
search that found it. Its job is locations and evidence; you apply the veto to what comes
back.

For each surviving finding, produce:

- `severity` - **must-fix** (the next change to this code will be wrong or will have
  to be made in several places; a contract that lies), **recommended** (real
  maintenance cost, no correctness trap), **minor** (cleanup worth doing while you
  are in there).
- `location` - `path:line`, plus every other location for a duplication finding.
- `principle` - which dimension it came from, in a couple of words.
- `finding` - one sentence: what is wrong and what it will cost later.
- `code context` - the current code as a fenced, language-tagged block, enough lines
  to stand alone, each line prefixed with its real line number.
- `proposal` - the concrete smaller shape, specific enough to act on. Name the
  existing helper, the constant to extract, the branch to collapse.
- `cost` - files touched and the net direction (fewer lines / same lines, more
  indirection). This is the veto's rule 4, shown to the reader.
- `outside the diff` - only when the fix reaches files the branch never touched: list
  them, say what the branch did that makes it a finding now (veto rule 7's three shapes),
  and give the evidence - the search you ran and the references you found or did not
  find. For a deletion this is the reference checklist; for a convergence finding it is
  the per-site migration list. Findings entirely inside the diff omit this field.

Group trivia into one finding (all the unused imports in one entry), never one
headline each. If nothing survives the veto, say that plainly and stop - do not pad
the report. A clean branch is a legitimate result and worth saying out loud.

## Step 4 - Report, ranked top to bottom

One flat numbered list, **most important first**, not grouped by file. Rank by
severity first, then by blast radius (how many call sites or future edits it
touches), then by how cheap the fix is. Number them so the user can say "fix 1 and 3".

For each finding, in this order: **severity and title**, **location(s)**, **code
context** (the line-numbered block), **finding**, **proposal**, **cost**, and
**outside the diff** when the fix reaches beyond it.

Rank a leftover-superseded finding high: it is cheap to fix, and two live paths to the
same behavior misleads everyone who reads the code next. Rank a convergence finding by
how many sites it collapses, and put it below the must-fix items when it is follow-up
work rather than part of this branch.

Then close with:

- **Verdict** - one or two sentences: is the design sound, and what must-fix items
  are open. Say so plainly when it is sound.
- **App context checked** - one or two lines on what the wider read covered: which added
  units you searched prior art for, what you confirmed is now orphaned, and what you
  confirmed is still live. This is how the reader knows the wider pass ran, and it is
  worth writing even when it found nothing.
- **Deliberately not flagged** - the things you considered and vetoed, one line each
  with the reason (usually "one call site and not generic enough to move", "only
  implementation", "shape not logic",
  "predates the branch", "still has live callers", "similar shape, different behavior").
- **Out of scope but worth noting** - bug / security / test / performance / a11y
  observations, each pointing at the owning skill.

Present the report inline in the conversation. Write no files.

## Step 5 - If the user asks for fixes

The default is report only. If the user names findings to fix ("do 1 and 4"), apply
each one as the smallest correct diff, one at a time, matching the surrounding style,
and show the real `git diff` for each. Then:

- Run only the cheap check on what you touched - compile / typecheck / lint for that
  component (`npx eslint --fix <path>` for `ui-app` files, a build of the touched
  project for C#). Report the real output; never claim a check you did not run. The
  test suite is a separate pass and belongs to `update-tests`.
- Do not commit or push unless the user asks (the global git rules).
- Do not fix anything that was not named, and do not expand a fix past the finding.

Two extra rules for the fixes that reach outside the diff:

- **A deletion gets re-verified and confirmed before it happens.** Re-run the reference
  search at fix time, show what it returned, and get an explicit go-ahead before removing
  a file. Then remove the whole thread in one go - the file, its barrel export, its route
  or DI registration, its story, its tests, its now-unused `en.json` keys - so the branch
  is not left half-cleaned. `en.json` only: never touch `fr.json`, `es.json`, `en-XA.json`
  or the XLIFF memory, the pipeline owns those. Never delete something the search still
  finds live references to.
- **A convergence migration goes one site at a time.** Refactor one call site onto the
  new unit, show the diff, run the cheap check, then move to the next. Stop and report if
  a site turns out to need behavior the shared unit does not have, rather than growing
  the unit to fit; that is a new decision for the user, not a fix. Say up front how many
  sites the user is agreeing to.

## Conventions

- The veto outranks the dimensions. A dimension violation that fails the veto is not
  reported as a finding.
- Read the code before claiming anything; cite `path:line`. No reviewing from a diff
  alone and no reviewing from memory.
- The diff anchors the review; the app is the context. Every finding traces back to what
  the branch did, and the ones that reach outside the diff say so and carry the search
  that proves them.
- Findings are ordered by importance in one flat list, so a reader who stops at three
  has handled the three that mattered.
- No em dash, emojis, arrows, or box-drawing characters anywhere in the report.
- Discovery never edits. Fixes happen only in Step 5, only for findings the user
  named.
