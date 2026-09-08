---
name: solidify
description: Design and maintainability review of the current branch, at two altitudes. The structural half asks whether each concept the code expresses has exactly one home, and is willing to recommend a large refactor when the evidence supports it; the maintainability half covers SOLID, DRY, superseded code, convergence, dead surface and coupled constants, ranked most important first. REVIEW AND PLAN ONLY - it changes no product code unless separately asked, and writes only its own report and specs under the gitignored `artifacts/solidify/`, which a later run picks up from. Discovery works by pairing each unit the branch introduced with its nearest sibling and diffing the two, so it runs as one sequential pass rather than a fan-out. Language-agnostic across the momentum monorepo (C# services and ui-app alike). Functional bugs, security, tests, performance and accessibility are out of scope and get handed to the skills that own them. Invoke when the user types /solidify, or asks "is this the right shape", "should this be split", "would a refactor pay here", "this code is clean but feels wrong", "check this for SOLID", "review for DRY", "am I duplicating anything", "is this maintainable", "code quality pass on my branch", or hands over a branch and asks whether the design holds up.
---

# solidify Skill

You review the current branch at **two altitudes**, from one set of reads.

- **Structural.** Does each concept the code expresses have exactly one home? This is
  the pass that catches locally-clean code carrying two ideas at once, and it prices a
  refactor rather than rejecting it for being big.
- **Maintainability.** SOLID, DRY, superseded code left behind, convergence on a unit
  the branch introduced, dead surface, coupled constants. The ordinary things that make
  code expensive to change later.

**Read [`../shared/structural-bar.md`](../shared/structural-bar.md) first.** It carries
the structural altitude, the pair-discovery frame, the ten tells, the seven-rule bar and
the not-a-finding list. It is binding and must not be paraphrased from memory. This file
carries the maintainability half, the scope, the phases and the report.

The two altitudes are not two passes. The pair diff that finds a structural concept is
the same read that shows you the superseded copy and the third duplication site, so
maintainability findings come out of evidence you already have rather than out of a
second sweep. That is what makes this cheap.

## One agent, sequential. Spawn nothing.

Earlier versions of this skill fanned out five concurrent lenses, and so did the
structural pass beside it. Both were expensive for the wrong reason: each lens read
substantially the same files in its own context, the orchestrator read them again
first, and the merge had to re-verify every site because the fragments arrived
pre-packaged.

Run the phases below **in order, in your own context**, finishing each and writing its
output before opening the next. The pair table, then the pair diffs, then the axis
check. A finding assembled from four tells is easier to see when one reader holds all
four, not harder.

## Hard boundary

In scope: concept placement, the shape of contracts and types, flags and discriminants
and where they are tested, what each caller can actually reach, vocabulary coherence,
single responsibility, open/closed, substitutability, interface segregation, dependency
inversion, DRY, naming, dead code, public surface width, coupled constants, shared-unit
blast radius, superseded code, convergence.

Out of scope. Note each in one line, name the owner, and do not run that review here:

- **Functional bugs, correctness, silent failures, security** -> `/code-review`,
  `/security-review`.
- **Tests and coverage** -> `loom-slice`, `loom-gate`. Test code is not reviewed here at
  all, not its design and not its duplication. You **read** specs as evidence (tell 9)
  and you never review them.
- **Performance**, unless the structure forces an algorithmic mistake.
- **Nuxt UI component choice, i18n, theming, accessibility.**

## The over-engineering veto

The structural bar gates the structural findings. This gates the **maintainability**
ones, and it is the point of that half: be strict and drop things.

1. **One call site raises the bar; it does not close the door.** The default is to wait
   for the second real use, and for polymorphism machinery it is a flat no: no
   interface, base class, generic parameter, factory, strategy, registry or plugin seam
   for a variation that does not exist yet. "It might be reused" is not a use.

   A plain extraction is different, and earns its keep on either count: **the host file
   gets better** (say roughly how many lines leave the caller and what the new unit is
   called), or **the unit is generic so a second use is likely** (it takes everything it
   needs as arguments, knows nothing about the caller's screen, carries no
   caller-specific flags, and its name would still be right elsewhere - name the
   plausible next caller). A unit that only makes sense where it sits fails this, and so
   does one that would need a flag per caller.

   Existing code elsewhere that already does the same thing by hand **does** count as a
   real use - cite it by `path:line`. One call site in the diff plus three hand-rolled
   copies is four uses, not one. A single-use extraction is **recommended** at best,
   more often **minor**, never must-fix.

2. **One implementation means no interface**, unless there is a real seam behind it (a
   boundary the code already crosses - clock, filesystem, HTTP, DB - or an existing DI
   registration the component already uses). Say which seam.
3. **Two is a note, three is a finding.** Rule of three for duplication. Two copies are
   reported only when they share an invariant that will silently drift, and then the fix
   is to name the value once, not to build a framework.
4. **The fix must pay for what it adds.** State files touched, indirection added, net
   lines. An extraction that adds a file but leaves the caller materially easier to read
   pays for itself, as long as the reader follows one hop and not three. What does not
   pay is more files, more hops, and a caller that reads exactly as before.
5. **No pattern names as justification.** Argue the fix by what it removes or what
   future edit it de-risks, in plain terms, or it is not a finding.
6. **The repo's existing pattern wins.** Match how the surrounding component already
   does this (nearest `CLAUDE.md`, sibling files) over generic best practice. A finding
   that asks the branch to be the one file in the component doing it differently is a
   wrong finding.
7. **Anchored to the branch's work, not confined to the diff.** Every finding traces
   back to something the change did, in one sentence, in one of three shapes: the change
   **superseded** it, the change **built the resolution** for it, or the change **made
   it materially worse** (added the third copy, widened the interface, built on the
   wrong seam). Say which, and say plainly when the root predates the branch. A wart
   fitting none of the three is a backlog item, and belongs at most in one line.
8. **Convergence must be worth the migration.** "Refactor the old components onto the
   new one" costs edits in files the branch never opened, so: at least two pre-existing
   sites, behavior genuinely the same rather than similar-looking, each site named with
   what changes there. If absorbing them all needs a flag or a variant per caller, the
   honest finding is "these are not the same thing" and you drop it. Where the migration
   is real but larger than the branch, recommend it as follow-up.

What fails the veto but is still worth a line goes in **Deliberately not flagged**, with
the rule that killed it.

## Step 0 - Scope

Run from the worktree root you are standing in.

```bash
git fetch origin main -q
git log origin/main..HEAD --oneline                 # the story the commits tell
git diff --stat origin/main                         # size and shape
git diff --name-only origin/main
git diff --diff-filter=A --name-only origin/main    # added: what might supersede something
git diff --diff-filter=D --name-only origin/main    # deleted: what was already cleaned up
git ls-files --others --exclude-standard            # new untracked files
```

No diff against `origin/main` and no named target: say so and stop.

If the user named a file, composable, component or subsystem instead, review that in
full. In that mode the target is the anchor, bar rule 1 reads against the target rather
than the branch, and veto rule 7's tracing requirement is waived.

Group by component (`src/<component>/`, `infrastructure/<x>/`), read the nearest
`CLAUDE.md` and the repo root's, and drop pipeline-generated files (`fr.json`, `es.json`,
`en-XA.json`, XLIFF, generated clients) - a defect visible there is reported against its
source. Do **not** drop spec files; they are evidence (tell 9).

Ask the user what the change is meant to replace when it is not obvious, and take their
answer as the map. Headless, infer it from commit messages and file names and state the
assumption.

### Pick up a prior run

```bash
ls artifacts/solidify/<branch>-report.md artifacts/solidify/<branch>/specs/ 2>/dev/null
ls artifacts/solidify2/<branch>-report.md 2>/dev/null    # runs from before the two skills merged
```

If a report is there, read it in full first and treat it as a starting position rather
than as truth:

- Its **cleared**, **Low** and **Deliberately not flagged** lists are settled work. Do
  not re-litigate an item unless the branch has changed the code it names. Say in your
  report that you inherited them.
- Each finding is still open, now fixed, or now wrong. Check the `path:line` sites
  before carrying it forward. A finding whose code has been reworked is re-derived from
  scratch, not copied. Bar rule 3 applies to an inherited site list exactly as it does
  to a fresh one.
- A finding recorded as **spec written** has a file under
  `artifacts/solidify/<branch>/specs/`. Update it rather than writing a second one.
- New commits since the recorded merge base are where the phases concentrate.

## Phase A - Pair up

The only discovery step, and it is greps and directory listings rather than reads. Run
the three searches from the shared bar for every unit the branch introduced or
substantially rewrote, plus the parallel-name check one level up.

Output a **pair table** before reading anything: the branch's unit, its candidate
sibling, and which search found it. A unit with no sibling gets a row saying so, and is
carried into Phase C and Phase E on its own.

## Phase B - Diff each pair

Read both sides in full and build the part-by-part table. Lines up row for row: a
structural candidate. Diverges after two rows: cleared, one line, move on.

Run the prose grep over the changed files while you are here:

```bash
grep -nE 'rather than|while |unless |in the other case|only when' <changed files>
```

Tells 2, 4, 5, 8, 9 and 10 all surface in this phase. For tell 9, a
`grep -n 'describe(\|it('` index of the two spec files is usually enough; a spec file is
rarely worth a full read.

Never assert a type, helper or consumer exists without having read it.

## Phase C - Axis check, on the branch's own units

Every mode flag, discriminant, enum and correlated-optional set the new or rewritten
units carry. For each, **every** site that sets or tests it, by `path:line`, and how many
levels it is passed through. Tells 1, 6 and 7.

This is scoped to the branch's units on purpose, which is what keeps it cheap: the set is
small because the units are few. Where a flag sits on a public type with more than about
three consumers, take the shared bar's one escalation and build the matrix for that type
alone.

For a TypeScript symbol, load the LSP once with `ToolSearch("select:LSP")`, then
`findReferences` on the export and `goToDefinition` through barrels. Try one `.vue` path
first: if it answers "No LSP server available for file type", the list is a floor, so
grep the `.vue` files too and say so. For C#, grep. Cite `path:line` either way.

## Phase D - Shared contracts

For each shared type, props contract or component the branch touched: how many places
declare what it accepts? Read the declarations, not every consumer. Members with three
different optionalities across three declarations, a prop with zero production
set-sites, a mirror interface claiming to be "exactly the props this page binds" - that
is tell 3 at declaration level, and it is where `bpDelete` H3 came from.

## Phase E - Maintainability, from what you already read

No new sweep. Run the dimensions below over the evidence Phases A to D produced: the
branch's units read in full, each pair's sibling, the axis sites, the shared
declarations. Where a dimension needs one more grep, run it; where it would need a
subsystem read, say what you could not judge instead of paying for it.

| # | Dimension | Flag | Do not flag |
| --- | --- | --- | --- |
| 1 | Single responsibility | A unit with two genuinely separate reasons to change where the split is **already visible** - two disjoint clusters of state, a method that both decides and performs, a component that fetches and renders where siblings separate the two | A long file that tells one story; a split whose seam you cannot draw in one sentence |
| 2 | Open/closed | The **second or third** parallel arm added to a conditional on one axis | The first branch; an extension point for a variation that does not exist |
| 3 | Substitutability | An implementation that lies about its contract: `NotSupportedException`, a silently no-op member, narrowing what a base accepts. Must-fix when a caller can reach it through the base type | |
| 4 | Interface segregation | A contract whose members the new consumer does not use while another wants a subset; one that forces stub members | An interface whose only implementation and only consumer both use all of it |
| 5 | Dependency inversion | New code constructing a concrete dependency inline (HTTP client, DB context, `DateTime.Now`, filesystem, config read) where the component already takes dependencies through DI | A plain data type, or a helper with no seam |
| 6 | DRY | Logic repeated in three or more places, or twice where the copies must agree to be correct. Count across the app. The pair table is usually the evidence | Same-looking code answering different questions - say so when you decide it |
| 7 | Coupled constants | A literal whose correctness depends on matching a value elsewhere: a size matching a sibling's padding, a timeout under a caller's, a key spelled twice, a limit matching a DB column. Trace each new constant and confirm they agree | |
| 8 | Naming, readability, dead code | Names that mislead (a `Get` that mutates, a plural holding one thing, a bool named for the negative), dead or commented-out code, unused params/props/returns, boolean flag parameters, comments narrating what the code says | |
| 9 | Public surface width | A member, prop, export or return value made public that no consumer reads; access widened past what tests need. `internal` plus `InternalsVisibleTo` over `public` in C#; props down, events up in `ui-app` | |
| 10 | Shared-unit blast radius | A change to a shared component, composable, state or cookie key, extension method or base class that is correct for the caller in front of you and silently wrong for a sibling. Phase D's declarations plus the escalation cover this | |
| 11 | Superseded code left behind | The old component, file, endpoint, route, composable, DTO, constant, flag, `en.json` key or story the change replaced but did not remove. Follow every thread: imports, barrel and `index` re-exports, auto-import globs, routes, nav entries, DI registrations, `en.json` keys, `data-testid`, stories, config, openapi entries. Zero live references is a deletion finding; **live references on both paths is the worse finding** - say which case it is | A deliberate deprecation path (published contract, in-flight migration, marked obsolete). If it is undocumented the finding is the missing note, not the deletion |
| 12 | Convergence on the branch's own unit | Pre-existing code that should now sit on something the branch introduced. Bar is veto rule 8 | Sites that would need a flag or variant each to absorb |

**A caller may ask for structural only** - `m-pr-review` does, because it answers "is
it the right shape" and nothing else. Then skip this phase, and report anything you
noticed in passing as Low one-liners.

Dimensions 1, 2, 4 and 6 **escalate** when the pair table shows the same idea in two
homes: then it is structural, not maintainability, and it goes through the seven-rule bar
instead of the veto. That escalation is the whole reason both altitudes live in one skill.

## Step 2 - Assemble and judge

1. **Assemble before you dedupe.** Follow the shared bar's assemble rule: a flag's site
   count, an empty rectangle, a dual-meaning comment and a two-home concept are usually
   one finding seen four ways.
2. **Sort by altitude, mechanically.** **Structural** is a concept with more than one
   home, so the next change to it is made in several places and nothing fails if you do
   only some of them; it must clear all seven bar rules. **Maintainability** is
   everything else that clears the veto. **Low** is what is worth writing down and does
   not clear either: one line, no proposal. If you cannot show a second home, it is not
   structural however much you dislike the code.
3. **Rank structural by the price of the next change**, not by textbook severity. Cap at
   three. A branch with four is one you have misjudged or one that needs a design
   conversation rather than a review: say which.
4. **Rank maintainability** by severity (**must-fix** / **recommended** / **minor**),
   then blast radius, then how cheap the fix is. Rank a leftover-superseded finding
   high: it is cheap and two live paths mislead everyone. Group trivia into one entry.
5. **Re-run the veto over the merged set.** Two proposals that each pay for themselves
   separately may not pay together on the same file.
6. **Resolve contradictions.** Asking for a shared unit and asking to split the same code
   are the same lines pulled two ways. Decide, keep one, record the other as not flagged.
7. **Never forward an unverified site list or file count.**

A clean result is a legitimate result. An empty structural list with a real cleared list
is a good outcome, and it is worth saying plainly rather than padding.

## Step 3 - The report

**Write the report to a file, and print a short version in the chat.** The file is what a
later run picks up from; the chat version is what the user reads now.

```
artifacts/solidify/<branch>-report.md      # the report
artifacts/solidify/<branch>/specs/*.md     # any spec you are asked to write
```

`artifacts/` is gitignored in momentum, so nothing here reaches a commit or a PR. Create
the directories if needed. Name the report for the branch, not the date, so a second run
updates it in place.

The chat version is the summary, the findings index, and the structural findings' concept
plus price lines. Point at the file for the rest rather than pasting it twice.

The file opens with a header block - branch, merge base, date, components, the pair table,
files read in full, specs written, and a status line saying review only and whether any
code was changed - then two or three sentences on what the branch did and whether the
shape it landed in is the one to keep. Then a **findings index** (id, altitude, concept or
title, homes or severity, status), then the findings.

### Structural

Ids `S1`, `S2`, `S3`, ranked by the price of the next change. Each carries:

- **concept** - the idea in one noun phrase (bar rule 2)
- **where it lives now** - the part-by-part table, every site, `path:line`, complete
  (rule 3)
- **the tells** - which fired, with the quoted comment, the empty rectangle or the site
  count as evidence
- **price of the next change** - files touched today by change X, by name; files after
  (rule 4)
- **target shape** - type signatures, file names, component boundaries, specific enough
  to build from
- **staged plan** - numbered stages, each compiling and passing on its own (rule 5)
- **must survive** - the behaviors the refactor may not change (rule 6)
- **cost** - files added, files touched, specs split, net line direction, an honest word
  on the test bill
- **the case against** - the strongest argument for leaving it alone (rule 7)

A finding whose fix you could not stage still belongs here if the concept repeats - say
plainly that it is a rewrite rather than a refactor, and where the stageable half is.

### Maintainability

One flat numbered list, most important first, so a reader who stops at three has handled
the three that mattered. Each: **severity and title**, **location(s)**, **code context**
(a fenced, language-tagged block with real line numbers), **finding** (one sentence: what
is wrong and what it costs later), **proposal** (name the existing helper, the constant to
extract, the branch to collapse), **cost** (files touched, net direction), and **outside
the diff** when the fix reaches files the branch never opened - list them, say which of
veto rule 7's three shapes makes it a finding now, and give the search behind it. For a
deletion that is the reference checklist; for a convergence finding, the per-site
migration list.

### Low

One table, ids `L1`, `L2`, ... One row each, no analysis and no proposal. Cite `path:line`
and say in a clause whether it is pre-existing or the branch's. A later run inherits this,
so a vague row costs someone a re-read.

Then, in short lists:

- **Cleared** - the pairs that diverged and the central units that are structurally fine,
  one line each with why. Write it so a later run does not re-litigate them.
- **Coverage** - the pair table with what each search returned, files read in full, greps
  and `findReferences` run, the escalations you paid for, any method caveat (an
  unavailable LSP, a grep-only reference list), and **what the frame could not reach**
  (the shared bar's stated blind spots: a smear with no pair and no shared declaration, a
  pre-existing smear between two untouched units).
- **Deliberately not flagged** - considered and vetoed, one line each with the rule.
- **Out of scope** - bug, security, test, performance, a11y observations, each pointing at
  the owning skill.

Offer at the end to write a structural finding up as a spec, or to implement its stage 1.
Do neither unless asked.

### Writing a spec when asked

Build it from `docs/spec-template.md` and write it to
`artifacts/solidify/<branch>/specs/<kebab-slug>.md`. Not into `src/<component>/specs/`:
that path is for specs that ship with the component, and a review's proposal is not one
until someone decides to build it.

Keep the spec to requirements - WHAT and WHY plus acceptance criteria in the template's
EARS phrasing. The target shape, the staged plan and the signatures stay in the report
because they are the HOW. A refactor's requirements are mostly invariance requirements, so
the finding's **must survive** list is what turns into acceptance criteria. Record the
spec's path in the header block and set that finding's index status to **spec written**.

## Step 4 - If the user asks for fixes

The default is review only. If the user names findings ("do 1 and 4", "take S1 stage 1"),
apply each as the smallest correct diff, one at a time, matching the surrounding style,
and show the real `git diff` for each. Then run only the cheap check on what you touched -
compile, typecheck or lint for that component (`npx eslint --fix <path>` for `ui-app`, a
build of the touched project for C#). Report the real output; never claim a check you did
not run. The test suite is a separate pass and belongs to `loom-slice` / `loom-gate`.

Do not commit or push unless asked. Do not fix anything that was not named, and do not
expand a fix past the finding.

Two extra rules for fixes reaching outside the diff:

- **A deletion gets re-verified before it happens.** Re-run the reference search at fix
  time, show what it returned, and get an explicit go-ahead. Then remove the whole thread
  in one go - the file, its barrel export, its route or DI registration, its story, its
  tests, its now-unused `en.json` keys. `en.json` only: never touch `fr.json`, `es.json`,
  `en-XA.json` or the XLIFF memory. Never delete something the search still finds live
  references to.
- **A convergence migration goes one site at a time.** One call site, show the diff, run
  the cheap check, next. Say up front how many sites the user is agreeing to. Stop and
  report if a site needs behavior the shared unit does not have, rather than growing the
  unit to fit: that is a new decision, not a fix.

## Conventions

- One agent, phases in order, spawn nothing. The pair frame is what replaced the fan-out.
- Discovery is read-only and writes only the report and specs under `artifacts/solidify/`.
- Two altitudes, one mechanical test between them: a second home makes it structural.
- The bar gates structural findings, the veto gates maintainability ones. A dimension
  violation that fails the veto is not reported as a finding.
- Read the code before claiming anything; cite `path:line`. No reviewing from a diff alone
  and none from memory.
- The diff anchors the review; the app is the context. A finding reaching outside the diff
  says what the branch did to make it a finding now, and carries the search that proves it.
- Say what the frame could not reach. An honest blind spot beats a claim of completeness.
- No em dash, emojis, arrows or box-drawing characters anywhere in the report.
