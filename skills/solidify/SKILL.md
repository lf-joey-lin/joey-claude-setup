---
name: solidify
description: Review the current branch's work for SOLID, DRY, and code maintainability quality only, and report the findings as one flat list ranked most to least important. REVIEW ONLY, no edits unless separately asked. Language-agnostic across the momentum monorepo (C# services and ui-app alike). Every finding must survive an over-engineering veto first - no abstraction proposed for a single call site, no interface for a type with one implementation, no pattern that adds more indirection than it removes - so what comes back is a short list of real maintainability defects, not textbook advice. Functional bugs, security, tests, performance, and accessibility are explicitly out of scope and get handed to the skills that own them. Invoke when the user types /solidify, or asks to "check this for SOLID", "review for DRY", "am I duplicating anything", "is this maintainable", "code quality pass on my branch", or hands over a branch and asks whether the design holds up.
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

## Hard boundary: maintainability only

In scope: the dimensions in Step 2 - single responsibility, open/closed,
substitutability, interface segregation, dependency inversion, DRY / duplication,
naming and readability, dead code, public surface width, coupled constants, and
shared-unit blast radius.

Out of scope, hand each to its owner and do not fold it in here:

- **Functional bugs, correctness, silent failures, security** -> `/code-review`,
  `/security-review`.
- **Tests and coverage** -> the `update-tests` skill. You may note that a design
  makes something untestable when that is the maintainability defect, but you do
  not write or judge tests.
- **Performance** unless the change makes an algorithmic mistake that is also a
  design mistake. A micro-optimization is not a solidify finding.
- **Nuxt UI component choice, i18n, theming tokens, accessibility** in `ui-app`
  -> `review-ui` and `implement-ui` own those. Do not re-litigate them.

If you spot one of these while reviewing, do not fix it. Collect it under "Out of
scope but worth noting" at the end of the report, pointing at the owning skill.

## The over-engineering veto (run before every finding)

A finding is only reported if it passes **all** of these. This is the point of the
skill; be strict and drop things.

1. **One call site means no abstraction.** Do not propose an interface, base class,
   generic, composable, helper, factory, or extracted module for code used in a
   single place. Wait for the second real use. "It might be reused" is not a use.
2. **One implementation means no interface.** Extracting a contract for a type with
   one implementation only earns its keep when there is a real seam behind it (a
   boundary the code already crosses - clock, filesystem, HTTP, DB - or an existing
   DI registration the surrounding component already uses). Say which seam.
3. **Two is a note, three is a finding.** Rule of three for duplication. Two copies
   are reported only when they share an invariant that will silently drift (they must
   agree for the code to be correct), and then the fix is to name the value once, not
   to build a framework.
4. **The fix must remove more than it adds.** State the cost of every proposal in
   concrete terms: files touched, indirection added, net lines. If the proposal ends
   with more files, more hops to read, and identical behavior, drop it.
5. **No pattern names as justification.** If you cannot argue the fix in plain terms
   by what it removes or what future edit it de-risks, it is not a finding. "Use a
   strategy pattern here" on its own is not an argument.
6. **The repo's existing pattern wins.** Match how the surrounding component already
   does this (nearest `CLAUDE.md`, sibling files) over generic best practice. A
   finding that asks the branch to be the one file in the component doing it
   differently is a wrong finding.
7. **Stay on the branch's own work.** Only flag what the change introduced or
   touched. A pre-existing wart is reportable only when the change makes it
   materially worse (the change added the third copy, widened the interface, or built
   on the wrong seam) - and then say explicitly that the root of it predates the
   branch.

When something fails the veto but you still think it is worth one line, put it in a
short "Deliberately not flagged" list at the end of the report with the reason. That
is how the reader knows you looked and decided, rather than missed it.

## Step 0 - Establish the scope

Review the current branch against the latest `origin/main`, including committed,
staged, unstaged, and new files. Run from the worktree root (e.g.
`~/m-code/momentum` or the feature worktree you are standing in):

```bash
git fetch origin main -q
git diff --name-only origin/main          # tracked changes: committed + staged + unstaged
git diff --stat origin/main               # size of the change
git ls-files --others --exclude-standard  # new untracked files
```

This repo is jj-colocated, so `git rev-parse HEAD` and `git branch --show-current`
are unreliable (see the root `CLAUDE.md`). Compare against `origin/main` directly as
above rather than resolving `HEAD` yourself; if you need the merge base, use
`git merge-base origin/main HEAD` and sanity-check the file list looks like the work
the user described.

If there is no diff against `origin/main`, say so and stop - there is nothing to
review. If the user named a specific file, class, or component instead, review that
target in full and the no-diff stop does not apply.

Then group the changed files by component (`src/<component>/`, `infrastructure/<x>/`,
`tests/`) - the review runs per component, because that is the unit that carries its
own conventions.

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

## Step 2 - The dimensions

Run each dimension against the changed code. Each one says what to flag and, just as
importantly, what not to.

1. **Single responsibility.** Flag a class, component, composable, or function that
   has two genuinely separate reasons to change, where the split is **already visible
   in the code** - two disjoint clusters of fields or state, a method that both
   decides and performs, a component that both fetches and renders in a codebase
   whose siblings separate the two. Do not flag a file for being long, and do not
   propose a split you cannot draw the seam of in one sentence.

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
   twice where the copies must agree to be correct. Same-looking code that answers
   different questions is not duplication, and coupling it is the worse outcome - say
   so when you decide that. Name every location. The proposal should be the smallest
   thing that removes the drift: one named constant, one call, one existing helper
   already in the repo. Prefer moving a duplicate to the helper that already exists
   over inventing a new one.

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

## Step 3 - Discover the findings

Discovery is **read-only**. It makes no edits, in any mode.

- **A small change** (one component, a handful of files) - review it inline. Do not
  spin up machinery for a 200-line diff.
- **A change spanning several components** - dispatch one `general-purpose` subagent
  per component, run concurrently, each seeded with that component's changed files,
  its `CLAUDE.md` path, and this skill's veto (rules 1 through 7) and dimensions
  quoted verbatim - the subagent does not have this file loaded. Keep the diff reading
  out of your own context and let each report back.

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

Group trivia into one finding (all the unused imports in one entry), never one
headline each. If nothing survives the veto, say that plainly and stop - do not pad
the report. A clean branch is a legitimate result and worth saying out loud.

## Step 4 - Report, ranked top to bottom

One flat numbered list, **most important first**, not grouped by file. Rank by
severity first, then by blast radius (how many call sites or future edits it
touches), then by how cheap the fix is. Number them so the user can say "fix 1 and 3".

For each finding, in this order: **severity and title**, **location(s)**, **code
context** (the line-numbered block), **finding**, **proposal**, **cost**.

Then close with:

- **Verdict** - one or two sentences: is the design sound, and what must-fix items
  are open. Say so plainly when it is sound.
- **Deliberately not flagged** - the things you considered and vetoed, one line each
  with the reason (usually "one call site", "only implementation", "shape not logic",
  "predates the branch").
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

## Conventions

- The veto outranks the dimensions. A dimension violation that fails the veto is not
  reported as a finding.
- Read the code before claiming anything; cite `path:line`. No reviewing from a diff
  alone and no reviewing from memory.
- Findings are ordered by importance in one flat list, so a reader who stops at three
  has handled the three that mattered.
- No em dash, emojis, arrows, or box-drawing characters anywhere in the report.
- Discovery never edits. Fixes happen only in Step 5, only for findings the user
  named.
