---
name: craft
description: Take an implementation request for ui-app, design it so the shape would survive a /solidify review, show that design to the human for approval, then build it. The design half scans the branch and the app for precedent, names the concepts the change adds and the one home each gets, picks the platform units that already do the work, and prices any refactor the change forces - then presents it as a short brief: a file map, one line per new unit, the ideas, the refactors, and what was deliberately not built. Nothing is written until the human approves, unless --solo runs the whole round unattended on the design's own top recommendation. The build half writes production code only. No tests, no coverage, no docs, no probes: /harden owns the suite. Invoke when the user types /craft, or asks to "design this first", "just design and build it without asking", "plan it properly then build it", "what shape should this be", "design and implement", or hands over a ui-app feature and wants the shape agreed before any code exists.
---

# craft: design it clean, get it approved, build it

Two acts, one skill.

1. **Design.** Scan the branch and the app, then write a design whose shape would
   survive `/solidify`: every concept with exactly one home, no machinery for a
   variation that does not exist, the platform units that already do the work taken
   rather than hand-rolled. Present it and stop.
2. **Build.** Once the human approves, write the production code the design calls
   for and the cheapest check that proves it compiles and lints.

`--solo` closes the gap: the design still gets written and printed, and the round
then builds it without asking. Same bar, same brief, no pause.

The gap between the two is the point of the skill. Most bad shapes in this app were
not decided, they accumulated one reasonable-looking file at a time. Deciding out
loud, once, before any code exists, is cheaper than a refactor found in review.

**No tests.** Not written, not run, not counted. `/harden` owns the suite and reads
this branch's diff as its input.

## Invocation

```
/craft <request>                 # scan, design, ask, build
/craft <request> --solo          # unattended: zero asks, builds the top recommendation
/craft <request> --in <dir>      # work in a worktree the human already has
/craft <request> --design-only   # stop after the brief
/craft --build                   # the brief is already approved: build it
/craft <request> --visual        # also publish the brief as an artifact
```

`<request>` is a sentence or a short bullet list. State the resolved shape in your
first line of output, before any tool call:
`Craft: <slug>   Mode: attended | solo   Round: <n>   Worktree: <path>`.

`--solo` and `--design-only` contradict each other. If both are passed, take
`--design-only`, the one that writes no code, and say so in your first line.

## Not the right skill when

- The request needs slices, probes and a gate: that is `/loom`.
- A plan already exists and the human wants code now: that is `/prototype`.
- The code exists and the question is whether the shape held: that is `/solidify`.

craft is the middle case: one coherent change, worth agreeing the shape of, small
enough that one design and one build round finishes it.

## Scope

**In:** `src/ui-app`, plus `src/acs-bff` or `src/app-bff` when the design needs a
browser-facing route the app cannot already reach. A BFF route is designed through
[`../api-integrator/SKILL.md`](../api-integrator/SKILL.md) Steps 0 to 4, and its
material (upstream route with where you read it, the browser route and verb, the DTO
field for field with what is dropped, the status map) goes in the brief. Its own
Step 5 approval gate is not run separately; this skill's ask moment is that gate,
and under `--solo` it is defaulted along with everything else.

**Out, without asking:** unit tests, the test suite, coverage, mutation testing,
storybook stories, the a11y run, docs, READMEs, changelogs, comments elsewhere in
the repo, refactors the design did not call for, committing, pushing. Name the gap
in the handoff; do not fill it.

## Binding files

Read before designing, and do not paraphrase either from memory:

- [`../shared/structural-bar.md`](../shared/structural-bar.md) - what a concept is,
  the three searches that find a unit's nearest sibling, and the tells. The scan in
  Step 2 and the bar in Step 3 are both derived from it.
- [`../shared/loom-contract.md`](../shared/loom-contract.md) - the repo facts:
  workspace layout, the platform rosters and where they are typed, the command
  table, the git and i18n rules.

`src/ui-app/CLAUDE.md` is binding too, and its **Component organization** rules are
what decide where each new unit lives. That decision belongs in the brief.

## Hard stops

Stop and report; never work around.

- **The default worktree is read-only.** `<root>/momentum` stays on main. Never
  branch, commit or edit there, even when it is clean.
- **The branch is `main`.**
- **`en.json` only.** `fr.json`, `es.json`, `en-XA.json` and the XLIFF memory are
  pipeline output.
- Anything that looks like a secret.

## Run inline. Spawn nothing.

One agent, steps in order. The scan is bounded by construction (greps and
directory listings, then a handful of full reads), the design comes out of what
that scan returned, and the build is a short diff. A fan-out here would re-read the
same files in three contexts and hand back fragments that have to be re-verified.

## Step 1 - workspace

Derive `<slug>` (kebab-case) and, if a branch is needed, `<branch>` (camelCase).

- **`--in <dir>`, or the session is already standing in a `momentum-<x>` worktree:**
  use it as it is. Create nothing, reset nothing, never touch uncommitted work.
- **The session is in `<root>/momentum`:** that checkout is read-only, so make a
  worktree of your own:

  ```bash
  git -C "<root>/momentum" fetch origin
  git -C "<root>/momentum" worktree add --no-track -b <branch> "<root>/momentum-<slug>" origin/main
  ```

  Then `npm ci` in `<root>/momentum-<slug>/src/ui-app`. A fresh worktree has no
  `node_modules`, and the postinstall runs `nuxt prepare`, which writes the
  `.nuxt/imports.d.ts` roster the scan greps. Design against a missing roster and
  you design against memory. A failed install is reported, not fatal.

  If the worktree name is taken, stop and report. Never clobber.

Everything after this step runs from the worktree root, with absolute paths.

## Step 2 - the scan, before the design

The scan runs first, always. A design written before it is a design the scan
rewrites: the precedent it turns up changes where units live, which of them are
needed at all, and whether the request is mostly wiring something that already
exists. Both halves are cheap and neither is a review.

### The branch half

What work is already here, so the design extends it instead of duplicating it.

```bash
git fetch origin -q
git log origin/main..HEAD --oneline
git diff --stat origin/main
git diff --name-only origin/main
git status --porcelain
ls artifacts/craft/<branch>-design.md 2>/dev/null
```

A design file already there means this is a later round: read it in full, and treat
its approved shape as the starting position rather than redesigning around it.

### The app half

Three searches per unit the request will introduce, straight from the structural
bar, plus the platform sweep. Greps and listings, not reads.

1. **Same folder.** What sits beside where this will live, doing the same kind of
   job, and any shared helper already there.
2. **Other consumers of something shared it will import.** Who else reaches for the
   component, composable or type this will reach for.
3. **Vocabulary.** The request's two or three most distinctive nouns, grepped
   app-wide. This is the one that finds a sibling sharing no import.

Then the **platform sweep**, per behavior rather than per component. Write the
behaviors down in plain words first, including the ones nobody thinks of as
components: loading more as a list ends, debouncing an input, trapping focus,
reading an element's size, watching it enter the viewport, persisting a preference,
copying to the clipboard, reacting to the page going hidden. For each, find what
already does it, in the contract's order: an app component or composable, a Nuxt UI
component, a Nuxt or Vue built-in, a VueUse composable, composition of those,
custom.

```bash
ls src/ui-app/app/components/ src/ui-app/app/composables/ src/ui-app/app/utils/
ls src/ui-app/node_modules/@nuxt/ui/dist/runtime/components/
grep -i '<behavior>' src/ui-app/.nuxt/imports.d.ts
grep -i '<behavior>' src/ui-app/node_modules/@vueuse/core/dist/index.d.ts
```

List the Nuxt UI roster for every behavior that renders anything, even when you
think you know the answer. It is one `ls` and it is the roster the design defaults
to, so skipping it is how a hand-roll gets designed by accident.

Never name a component, composable or prop you have not confirmed in one of those
rosters. `@vueuse/core` is a declared dependency with a live consumer in `app/`, so
taking one is an ordinary choice needing no approval; it is not auto-imported, so it
costs one explicit `import`.

**Read in full only what the design will sit on**: the nearest sibling of each new
unit, the file each edit lands in, and the declaration of any shared type or props
contract the change touches. Everything else stays a grep with a `path:line` cite. A
scan that starts reading a subsystem has stopped being a scan.

## Step 3 - design

Design in this order. The order matters: units chosen before concepts are units that
end up holding two ideas.

1. **Name the concepts the change adds**, each as one noun phrase with no "and":
   "what the current filter is", "how a listing reads its next rows". Then name the
   one file that owns each. A concept with two owners in your own design is the
   defect this skill exists to prevent, and it is free to fix now.
2. **Assign each behavior to what already does it**, from the sweep, at a
   `path:line`, taking the platform unit unless rule 5 below says otherwise. What is
   genuinely left over is what you write, and that list should be short.
3. **Place each new unit** by `src/ui-app/CLAUDE.md`'s component-organization rules:
   reused or layout-rendered goes to `components/common/`, one feature's goes to
   `components/<feature>/`, page or business logic never goes in `common/`, every
   component gets its own kebab-case folder, and a filename is unique across
   `components/`.
4. **Name what this supersedes**, and plan its deletion in the same design: the
   file, its barrel or auto-import reach, its route, its nav entry, its story, its
   `en.json` keys, its `data-testid`. Two live paths doing one job is worse than the
   old code standing untouched.
5. **Price any refactor the change forces**, and only those (see below).
6. **Run the bar.** Then write the brief.

### The refactors, and only the ones the change forces

A refactor belongs in the brief when the change makes it necessary, in one of three
shapes: the change **supersedes** the old code, the change **builds the resolution**
for a smear that already exists, or the change **makes it materially worse** (adds
the third copy, widens a shared contract, builds on the wrong seam). Say which.

Each one carries, or it is not in the brief:

- **concept** - the idea in one noun phrase.
- **homes today** - every site, by `path:line`, complete. Say whether the list came
  from the LSP or from grep.
- **what moves** - the target shape, specific enough to build from.
- **price of the next change** - a realistic next edit to this area, files it
  touches today by name, files after.
- **stages** - numbered, each one compiling and linting on its own.
- **must survive** - the behaviors it may not change.
- **the case against** - the strongest argument for leaving it alone, stated fairly.

Cap at two. Three refactors in one brief means this is a design conversation or a
`/solidify` run, not a craft round: say so and ask which one the human wants.

### The bar, run before the brief is shown

The failure mode of a design-first skill is generating architecture. Nine of these
ten are there to stop that, and dropping something is the normal outcome.

1. **Every unit's job is one sentence with no "and".** If it needs "and", either the
   split is real and the design makes it, or there is no unit there.
2. **No new mode.** A boolean, enum, discriminant or mode prop only when **two cases
   ship today**. One case is a hard-coded answer with a switch in front of it: write
   the answer. A second case expected later is the same thing with optimism
   attached.
3. **No machinery for a variation that does not exist.** No interface, base class,
   generic parameter, factory, strategy, registry or plugin seam for one
   implementation. An interface needs a seam the code already crosses (clock, HTTP,
   DB, filesystem) or a DI registration the component already uses. Name it.
4. **An extraction earns its keep.** Rule of three across the app, and existing
   hand-rolled copies count as real uses - cite them by `path:line`. Two copies only
   when they share an invariant that will silently drift, and then the fix is naming
   the value once, not building a unit. A single-use extraction needs either a host
   file that gets materially better (say roughly how many lines leave) or a unit
   generic enough that a second caller is likely (name the plausible one).
5. **Platform before hand-rolled**, per behavior, confirmed at `path:line`, in the
   contract's order. Anything with markup lands on a Nuxt UI `U*` component by
   default, dressed through its own props, slots and `ui` overrides. A thin wrapper
   around the stock component is still taking the platform, and it is the right move
   when the app wants one shape in every screen.

   Hand-rolling has to pay for itself, and the bar is a much better outcome, not a
   tie. Name the unit passed over, say what it could not do, and say why living with
   that is worse than owning the markup from here on. It clears the bar when the
   stock component cannot reach the behavior at all, or when the overrides needed to
   get there are harder to read than the component you would write instead. It does
   not clear on "nothing imports it yet", "it is only fifteen lines", "the props are
   awkward" or a styling preference. Fifteen lines of lifecycle and teardown is
   where the edge cases live, and a wrapper around `UModal` picks up every fix in
   the next Nuxt UI bump for free.
6. **One home per concept, in your own design.** Walk each idea and check it is
   tested, decided or held in exactly one file. A predicate the page tests and the
   composable tests too is one concept in two homes, and here it costs a line to fix.
7. **The repo's pattern wins.** The nearest sibling and the nearest `CLAUDE.md` over
   generic best practice. A design that makes this the one file in the component
   doing it differently is a wrong design.
8. **Nothing ships with two live paths.** Step 3.4's deletion list is complete, or
   the brief says plainly what is being left and why.
9. **Constants named once.** Any literal whose correctness depends on matching
   something elsewhere - a size matching a sibling's padding, a key spelled twice, a
   limit matching a column - is named in one place, and the brief says where.
10. **Surface as narrow as it can be.** Props down, events up. Nothing exported that
    no consumer reads.

**A small design is the normal good result.** No new abstraction, no refactor, three
edited files and two `en.json` keys is a design that passed. If the brief's new-units
block is longer than the request, you have designed past it: cut back to what the
request asked for and put the rest in the brief's own not-built block.

## Step 4 - the brief

Write the full version to `artifacts/craft/<branch>-design.md` (`artifacts/` is
gitignored, so nothing here reaches a commit), and print the short version in chat.
A later round appends `## Round <n>` rather than reopening a finished section.

Six blocks, in this order, and keep it skimmable. This is the whole interface to the
human, so it is short on purpose: they need to say yes or point at one thing.

**1. The idea.** One short paragraph: what the human will be able to do afterwards,
and the concept the change adds, named. Then one flow line per path the change
creates:

```
RepositoryIndex.vue -> useRepositoryFilter -> repositoryService.list() -> GET /api/repositories
```

**2. The map.** An ASCII tree of the touched area, `+` new, `~` changed, `-` deleted,
with one clause per line saying what it is for. This is the block that carries the
design: a reader who sees only this should know where everything lives.

```
src/ui-app/app/
  pages/repository/
    ~ index.vue                    binds the filter bar, no logic added
  components/repository/
    + repository-filter/
        + RepositoryFilter.vue     renders the filter controls, emits the choice
  composables/
    + useRepositoryFilter.ts       holds what the current filter is, nothing else
    - useRepoQuery.ts              superseded, 2 call sites, both moved
i18n/
  ~ en.json                        5 keys under repository.filter
```

**3. New units.** One row each: the unit, its kind, its one-sentence job with no
"and", its home and the placement rule that put it there, and the platform unit it
stands on at `path:line`. A row with nothing in that last column is a hand-roll, so
it carries the Nuxt UI component it passed over and the reason instead, per bar
rule 5. A brief with several of those is a brief to reread before showing.

**4. The ideas.** One line per concept the change adds: the noun phrase, the one file
that owns it, and where the current code holds it instead if it already exists
somewhere. This is the block a later `/solidify` run reads back.

**5. Refactors.** Each per the fields above, or the single line "none: the change
supersedes nothing and adds no copy". Zero is a real answer and worth stating.

**6. Not built.** What you considered and dropped, one line each with the bar rule
that killed it. The abstraction you did not add, the flag you turned into a
hard-coded answer, the extraction that had one caller. This block is what makes the
rest trustworthy, so never leave it empty when you dropped something.

Then, if anything remains genuinely open, **Open questions** - only the ones where
two readings produce materially different code. Everything else takes the default
order (this app's precedent, then `src/ui-app/CLAUDE.md`, then the most idiomatic
Nuxt UI shape) and is recorded as defaulted with the alternative.

Under `--solo` there is no Open questions block. Every one of them takes the same
default order, and each is recorded in the brief as defaulted with the reading you
did not take, so the human can see what was decided for them in one place.

### `--visual`

Also publish the brief as an artifact: the map as a mermaid component graph (new
units, what they consume, what is deleted), the units table, and the refactor prices.
Worth it for a design spanning several folders or a BFF route, overkill for three
files. The chat brief is still printed either way; the artifact is an addition, never
the only copy.

## Step 5 - the ask

One `AskUserQuestion`, and it is the only pause in the run. Ask the approval
question plus at most three of the open questions in the same call.

Approval options: **Build it** / **Change something** (they say what; rewrite the
brief and re-show it, without rerunning the scan) / **Design only, stop** (the file
stays for a later `/craft --build`).

Under `--design-only`, skip the ask, print the brief and stop. Do not start
building on a design nobody has agreed to.

### `--solo`

Skip the ask and go straight to Step 6 on the brief as written. Print it first
anyway, and write the file: the design is the record of what got built, and it is
what a later round and a later `/solidify` read back.

What solo changes is who answers, not what gets asked. Nothing is loosened:

- The bar in Step 3 runs the same, and dropping things is still the normal result.
  A solo round that designs more than an attended one would has misread the flag.
- Every fork takes the default order and is logged as defaulted. Never fork
  alternatives and never build two versions of a close call.
- The hard stops still stop. A read-only worktree, `main`, a generated catalog or
  something that looks like a secret ends the round with a report, and so does the
  Step 6 case where the code fights the design. There is nobody to ask, so a
  blocker is a stop, never a guess.
- Nothing is committed or pushed, same as attended.

The handoff says the run was solo and lists every defaulted decision, because that
list is the review the human did not get up front.

## Step 6 - build

The approved brief is the contract. Build it, in this order:

1. **Refactor stages first**, one at a time, where the new code sits on them. Each
   stage compiles and lints before the next starts.
2. **Then the vertical path, end to end.** A screen that renders with real data
   beats a perfect mapper with nothing to click. Stub only where the brief says to.
3. **Then the rest of the units**, in the brief's own order.
4. **Then the deletions**, per the brief's list, in one go: the file, its exports,
   its route, its nav entry, its story, its now-unused `en.json` keys, its
   `data-testid`. Re-run the reference search at deletion time and show what it
   returned. Never delete something the search still finds live references to.

While building:

- Smallest diff that makes the brief real. Match the surrounding code.
- Repo style applies because complying is free: `<script setup lang="ts">`, `t()`
  with keys in `en.json` only, palette tokens never hex, semantic HTML first, no
  `var` in C#, no em dash, no emoji.
- Add `data-testid` as you go where `src/ui-app/CLAUDE.md` calls for it, using its
  `<feature>-<element>-<qualifier>` naming with entity ids and never indexes. That
  is markup, not test work, and adding it later means editing the same files twice.
- **If the code fights the design, stop and say so.** A unit that turns out to need
  a flag the brief refused, an upstream shape that is not what the brief says, a
  seam that is not where you thought: that is a design change, and it goes back to
  the human as one line rather than being absorbed silently. Small readings you had
  to pick go in the handoff's deviations instead. Under `--solo` the same line is
  the end of the round: report it and stop, rather than redesigning unwatched.

## Step 7 - verify

Only the components the diff touched. The exit code decides, never the log text.

| Touched | Run |
|---|---|
| `src/ui-app/**` | `cd src/ui-app && npx eslint <the files you changed>` then `npm run build` |
| a BFF project | `dotnet build src/<bff>/<bff>.slnx -c Release` |
| several C# projects | `npx nx run-many -t build --projects=<csv>` |

- Scope the lint to the changed files; `eslint .` is not the same cost.
- `npm run build` is the typecheck too. Once, at the end, not per file.
- Nothing here runs tests, coverage, storybook, a11y or Docker. If a check needs one
  of those to mean anything, say so in the handoff rather than running it.
- Fix what these report and re-run. Still failing after three rounds: hand it back
  with the real output rather than grinding.

## Step 8 - handoff

Short. The human wants to start clicking.

1. **Built** - one line per file, grouped by component, against the brief's map.
2. **How to exercise it** - the command (`cd src/ui-app && npm run dev`), the route,
   and the specific states worth trying.
3. **Checks** - lint and build, pass or fail, per component, with the real result.
4. **Deviations** - anything you read differently, skipped, or could not do, and why.
   Under `--solo`, every defaulted decision goes here too, one line each with the
   reading you did not take.
5. **Deliberately not done** - one line: no tests, no coverage, no stories, no a11y
   run, nothing committed. Then where it happens: `/harden` for the suite (it reads
   this diff, uncommitted included), then `/loom-finish` if the branch wants the full
   review tail, then `/paperwork` for the work item and the PR.

Leave the work uncommitted unless the human asks. Uncommitted is their review state,
and both `/harden` and `/loom-finish` read the working tree as input.

Then stop. Do not volunteer the next step, do not start on tests, do not commit.

## Iterating

Feedback on the built code repeats Steps 6 and 7 only, on the delta, with no rescan
and no new brief. Keep the handoff to what changed.

Feedback that changes the **shape** is a new round: append `## Round <n>` to the
design file with just the delta (the concepts it adds or moves, the map lines that
change, the not-built lines it settles), ask once, then build. A solo round skips
that ask like the first one did. Do not rewrite an approved earlier round; it is
the record of what was agreed.

## Conventions

- One agent, steps in order, spawn nothing.
- Exactly one ask moment, and none at all under `--solo`. Asking outside it is a
  bug in this skill; a fork with no documented answer takes the default order and
  is recorded as defaulted.
- Nothing is written to `src/` before approval, and under `--solo` not before the
  brief is on disk and printed. The design file and the brief are the only output
  of Steps 1 to 5.
- The bar is identical attended and solo. Attendance changes who answers the
  questions, never what the design is allowed to be.
- The bar gates the design, and dropping things is it working. A small design is a
  pass, not a thin one.
- Read before claiming; cite `path:line`. Never name a platform unit you have not
  confirmed in its roster, and never forward a site list you did not verify.
- Tests belong to `/harden`, the review tail to `loom`, the shape review after the
  fact to `/solidify`. craft does none of the three.
